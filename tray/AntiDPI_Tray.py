#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import ctypes
import json
import os
import re
import subprocess
import sys
import threading
import time
import traceback

import pystray
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.abspath(__file__))
STATE_DIR = os.path.join(ROOT, '_state')
def find_engine():
    for name in sorted(os.listdir(ROOT)):
        if name.startswith('Zapret2_Golden') and name.endswith('.ps1'):
            return os.path.join(ROOT, name)
    return None


ENGINE = find_engine()
TASK_START = 'AntiDPI Start'
TASK_STOP = 'AntiDPI Stop'
WAIT_TIMEOUT = 15
CREATE_NO_WINDOW = 0x08000000
MUTEX_NAME = 'AntiDPI-TrayMutex'
ERROR_ALREADY_EXISTS = 183


def show_error(title, message):
    threading.Thread(
        target=lambda: ctypes.windll.user32.MessageBoxW(0, message, title, 0x10),
        daemon=True).start()


DEBUG_LOG = os.path.join(STATE_DIR, 'tray_debug.log')


def debug_log(msg):
    try:
        if os.path.isfile(DEBUG_LOG) and os.path.getsize(DEBUG_LOG) > 200000:
            os.remove(DEBUG_LOG)
        with open(DEBUG_LOG, 'a', encoding='utf-8') as f:
            f.write(time.strftime('%H:%M:%S ') + msg.rstrip() + '\n')
    except Exception:
        pass


def show_info(title, message):
    threading.Thread(
        target=lambda: ctypes.windll.user32.MessageBoxW(0, message, title, 0x40),
        daemon=True).start()


def decode_console(data):
    return (data or b'').decode('cp866', errors='replace')


def is_running():
    try:
        out = subprocess.check_output(
            'tasklist /FI "IMAGENAME eq winws2.exe" /FO CSV',
            shell=True, stderr=subprocess.DEVNULL, creationflags=CREATE_NO_WINDOW
        )
        return 'winws2.exe' in decode_console(out)
    except Exception:
        return False


def wait_for_state(target_running, timeout=WAIT_TIMEOUT, interval=0.3):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if is_running() == target_running:
            return True
        time.sleep(interval)
    return is_running() == target_running


def run_task(task_name):
    try:
        result = subprocess.run(
            ['schtasks.exe', '/run', '/tn', task_name],
            capture_output=True, creationflags=CREATE_NO_WINDOW, timeout=15
        )
        text = decode_console(result.stdout) + decode_console(result.stderr)
        if result.returncode == 0:
            return True, ''
        low = text.lower()
        if any(w in low for w in ('уже запущена', 'уже запущено', 'выполняется', 'already running')):
            return True, ''
        return False, (text.strip() or 'код {0}'.format(result.returncode))
    except Exception as e:
        return False, str(e)


def task_state(task_name):
    try:
        r = subprocess.run(
            ['schtasks.exe', '/query', '/tn', task_name, '/fo', 'CSV', '/nh'],
            capture_output=True, creationflags=CREATE_NO_WINDOW, timeout=15
        )
        line = decode_console(r.stdout).strip()
        if line:
            return line.rsplit(',', 1)[-1].strip().strip('"').lower()
    except Exception:
        pass
    return ''


def wait_task_ready(task_name, timeout=40):
    deadline = time.time() + timeout
    while time.time() < deadline:
        state = task_state(task_name)
        if 'выполняется' not in state and 'running' not in state:
            return True
        time.sleep(0.5)
    return False


def task_exists(task_name):
    try:
        r = subprocess.run(
            ['schtasks.exe', '/query', '/tn', task_name],
            capture_output=True, creationflags=CREATE_NO_WINDOW, timeout=15
        )
        return r.returncode == 0
    except Exception:
        return True


def force_stop_winws2():
    try:
        subprocess.run(
            'taskkill /F /IM winws2.exe',
            shell=True, capture_output=True, creationflags=CREATE_NO_WINDOW, timeout=10
        )
    except Exception:
        pass


def read_json(path, default):
    try:
        with open(path, 'r', encoding='utf-8-sig') as f:
            return json.load(f)
    except Exception:
        return default


def write_json_atomic(path, data):
    tmp = path + '.tmp'
    with open(tmp, 'w', encoding='ascii') as f:
        json.dump(data, f)
    os.replace(tmp, path)


def fetch_profiles():
    try:
        result = subprocess.run(
            ['powershell.exe', '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass',
             '-Command', "& '{0}' -ListProfiles | Out-String -Width 260".format(ENGINE)],
            capture_output=True, creationflags=CREATE_NO_WINDOW, timeout=60
        )
        text = decode_console(result.stdout)
        profiles = []
        for line in text.splitlines():
            m = re.match(r'^\s*(\d+)\s+(\d+)\s+(.+?)\s*$', line)
            if m:
                profiles.append((int(m.group(1)), int(m.group(2)), m.group(3)))
        return profiles
    except Exception:
        return []


class AntiDPITray:
    def __init__(self):
        self.mutex = ctypes.windll.kernel32.CreateMutexW(None, False, MUTEX_NAME)
        if ctypes.windll.kernel32.GetLastError() == ERROR_ALREADY_EXISTS:
            show_info('AntiDPI', 'Трей уже запущен (иконка в системном трее).')
            raise SystemExit(0)

        self.profiles = []
        self.strategy = 4
        self.running = is_running()
        self.icon = None
        self.busy = False
        self.pending = None
        self.auto_start = '--auto-start' in sys.argv

        state = read_json(os.path.join(STATE_DIR, 'tray_state.json'), {})
        if isinstance(state.get('profile'), int) and state['profile'] > 0:
            self.strategy = state['profile']

        self._build()
        threading.Thread(target=self._load_background, daemon=True).start()

    def _load_background(self):
        tasks_ok = task_exists(TASK_START) and task_exists(TASK_STOP)
        if not tasks_ok:
            show_error(
                'AntiDPI — настройка',
                'Задачи планировщика не найдены.\n\n'
                'Один раз запустите:\n'
                'Create-Tasks.bat\n\n'
                'Появится единственный UAC-запрос, после этого управление\n'
                'из трея работает без всяких подтверждений.'
            )
        self.profiles = fetch_profiles()
        debug_log('bg load done: tasks ok=%r, profiles=%d' % (tasks_ok, len(self.profiles)))
        if self.icon:
            self._refresh_menu()
        if self.auto_start and tasks_ok:
            try:
                n = int(self.strategy)
            except Exception:
                n = 4
            debug_log('auto-start: strategy %d in 10s (waiting for network)' % n)
            if self.icon:
                try:
                    self.icon.title = 'AntiDPI: автозапуск стратегии {0}…'.format(n)
                except Exception:
                    pass
            time.sleep(10)=
            self._click(('on', n))


    def _make_image(self, color):
        img = Image.new('RGBA', (64, 64), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        draw.ellipse([8, 8, 56, 56], fill=color, outline=(255, 255, 255, 255), width=4)
        return img

    @staticmethod
    def _strategy_label(num, name):
        label = name if len(name) <= 48 else name[:45].rstrip('. ') + '…'
        return '{0}. {1}'.format(num, label)

    def _menu(self):
        toggle_text = 'Выключить AntiDPI' if self.running else 'Включить AntiDPI'
        items = [
            pystray.MenuItem(toggle_text, self._toggle, default=True),
            pystray.MenuItem('Перезапустить AntiDPI', self._restart),
            pystray.Menu.SEPARATOR,
        ]

        if self.profiles:
            families = {}
            for num, fam, name in self.profiles:
                families.setdefault(fam, []).append((num, name))
            fam_items = []
            for fam in sorted(families):
                entries = families[fam]
                sub = pystray.Menu(*[
                    pystray.MenuItem(
                        self._strategy_label(num, name),
                        lambda *a, n=num: self._switch(n),
                        checked=lambda *a, n=num: n == self.strategy,
                        radio=True,
                    ) for num, name in entries
                ])
                fam_items.append(pystray.MenuItem(
                    'Семья {0}  ({1}–{2})'.format(fam, entries[0][0], entries[-1][0]),
                    sub))
            strategy_menu = pystray.Menu(*fam_items)
        else:
            strategy_menu = pystray.Menu(pystray.MenuItem(
                'Список стратегий загружается…', None, enabled=False))

        items.append(pystray.MenuItem('Стратегия', strategy_menu))
        items.append(pystray.Menu.SEPARATOR)
        items.append(pystray.MenuItem('Статус', self._status))
        items.append(pystray.Menu.SEPARATOR)
        items.append(pystray.MenuItem('Выход', self._quit))
        return pystray.Menu(*items)

    def _build(self):
        color = (0, 200, 0, 255) if self.running else (150, 150, 150, 255)
        self.icon = pystray.Icon(
            'antidpi-tray',
            self._make_image(color),
            'AntiDPI: {0} · стратегия {1}'.format(
                'ВКЛ' if self.running else 'ВЫКЛ', self.strategy),
            self._menu(),
        )

    def _quick_visual(self):
        try:
            self.icon.icon = self._make_image(
                (0, 200, 0, 255) if self.running else (150, 150, 150, 255))
            self.icon.title = 'AntiDPI: {0} · стратегия {1}'.format(
                'ВКЛ' if self.running else 'ВЫКЛ', self.strategy)
        except Exception:
            debug_log('quick visual failed:\n' + traceback.format_exc())

    def _refresh_menu(self):
        try:
            debug_log('refresh: running=%r strategy=%r profiles=%d'
                      % (self.running, self.strategy, len(self.profiles)))
            if not self.icon:
                return
            self.icon.icon = self._make_image(
                (0, 200, 0, 255) if self.running else (150, 150, 150, 255))
            self.icon.title = 'AntiDPI: {0} · стратегия {1}'.format(
                'ВКЛ' if self.running else 'ВЫКЛ', self.strategy)
            self.icon.menu = self._menu()
            try:
                self.icon.update_menu()
            except Exception:
                debug_log('refresh: update_menu failed:\n' + traceback.format_exc())
        except Exception:
            debug_log('refresh EXCEPTION:\n' + traceback.format_exc())

    def _update(self):
        try:
            self.running = is_running()
        except Exception:
            debug_log('update: is_running failed:\n' + traceback.format_exc())
        self._refresh_menu()


    def _run_bg(self, work, label='action'):
        def wrapped():
            debug_log('%s: begin (running=%r)' % (label, is_running()))
            time.sleep(0.3)
            try:
                self._refresh_menu()
            except Exception:
                debug_log('%s: early refresh failed:\n%s' % (label, traceback.format_exc()))
            try:
                work()
            except Exception:
                debug_log('%s: EXCEPTION:\n%s' % (label, traceback.format_exc()))
            finally:
                self.busy = False
                self._update()
                debug_log('%s: end (running=%r)' % (label, is_running()))
                if self.pending:
                    intent = self.pending
                    self.pending = None
                    debug_log('executing queued: %s' % (intent,))
                    self._execute(intent)
        threading.Thread(target=wrapped, daemon=True).start()

    def _restart(self, *args):
        try:
            n = int(self.strategy)
        except Exception:
            n = 4
        self._click(('switch', n))

    def _toggle(self, icon, item):
        text = getattr(item, 'text', '') or ''
        if 'Включить' in text:
            self._click(('on', self.strategy))
        else:
            self._click(('off',))

    def _click(self, intent):
        kind, n = intent[0], (intent[1] if len(intent) > 1 else None)
        label = kind + (' ' + str(n) if n is not None else '')
        if self.busy:
            if self.pending is None:
                self.pending = intent
                debug_log('queued: %s' % label)
            else:
                debug_log('ignored (already queued %s): %s' % (self.pending, label))
            return
        self._execute(intent)

    def _execute(self, intent):
        kind, n = intent[0], (intent[1] if len(intent) > 1 else None)
        if kind in ('on', 'switch'):
            try:
                n = int(n)
            except Exception:
                debug_log('execute: bad profile %r' % (n,))
                return
        self.busy = True
        if kind == 'off':
            self.running = False
            self._quick_visual()
            self._run_bg(self._do_stop, 'toggle-off')
        elif kind == 'on':
            self.strategy = n
            self.running = True
            self._quick_visual()
            self._run_bg(lambda: self._do_start(n), 'toggle-on %d' % n)
        else:
            self.strategy = n
            self._quick_visual()
            def work():
                debug_log('switch to %d: stopping' % n)
                ok, err = run_task(TASK_STOP)
                if not ok:
                    debug_log('switch to %d: stop task failed %r' % (n, err))
                    force_stop_winws2()
                if not wait_for_state(False):
                    debug_log('switch to %d: stop timeout' % n)
                    show_error('AntiDPI', 'Не удалось остановить AntiDPI перед сменой стратегии.')
                    return
                debug_log('switch to %d: stopped, starting' % n)
                self._do_start(n)
            self._run_bg(work, 'switch %d' % n)

    def _start_task_safe(self, n):
        for attempt in range(3):
            try:
                write_json_atomic(os.path.join(STATE_DIR, 'tray_cmd.json'), {'Profile': int(n)})
                write_json_atomic(os.path.join(STATE_DIR, 'tray_state.json'), {'profile': int(n)})
                self.strategy = int(n)
            except Exception as e:
                return False, str(e)
            if not wait_task_ready(TASK_START):
                debug_log('start_safe %d: task busy 40s' % n)
                return False, 'Задача запуска не освобождается. Подождите полминуты и повторите.'
            ok, err = run_task(TASK_START)
            debug_log('start_safe %d: run_task -> %r %r' % (n, ok, err))
            if ok:
                return True, ''
            low = err.lower()
            if 'выполняется' in low or 'running' in low:
                continue
            return False, err
        return False, 'Задача запуска не освободилась после нескольких попыток.'

    def _do_stop(self):
        ok, err = run_task(TASK_STOP)
        if not ok:
            force_stop_winws2()
        if not wait_for_state(False):
            show_error('AntiDPI',
                       'AntiDPI не остановился за {0} сек. Попробуйте ещё раз.'.format(WAIT_TIMEOUT))
        self._update()

    def _do_start(self, n):
        ok, err = self._start_task_safe(n)
        if not ok:
            show_error('AntiDPI',
                       'Ошибка запуска стратегии {0}:\n{1}'.format(n, err))
            self._update()
            return
        if not wait_for_state(True):
            debug_log('do_start %d: winws2 NOT seen after start' % n)
            show_error('AntiDPI',
                       'Стратегия {0} запущена, но процесс winws2 не появился.\n'
                       'Смотрите свежий лог в <install dir>\\logs'.format(n))
        self._update()

    def _switch(self, n):
        self._click(('switch', n))

    def _strategy_name(self, n):
        for num, _, name in self.profiles:
            if num == n:
                return name
        return ''

    def _status(self, *args):
        if getattr(self, '_status_open', False):
            return
        self._status_open = True
        try:
            running_now = is_running()
        except Exception:
            running_now = False
        name = self._strategy_name(self.strategy)
        msg = 'AntiDPI: {0}\nСтратегия: {1}{2}'.format(
            'запущен' if running_now else 'остановлен',
            self.strategy,
            '\n' + name if name else '')
        def run():
            ctypes.windll.user32.MessageBoxW(0, msg, 'AntiDPI Статус', 0x40)
            self._status_open = False
        threading.Thread(target=run, daemon=True).start()

    def _quit(self, *args):
        self.icon.stop()

    def run(self):
        self.icon.run()


if __name__ == '__main__':
    app = AntiDPITray()
    app.run()
