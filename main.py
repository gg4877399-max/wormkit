import kivy
kivy.require('2.2.0')

from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.textinput import TextInput
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.scrollview import ScrollView
from kivy.clock import Clock
from kivy.core.window import Window
import threading
import json
import time
import requests

if hasattr(Window, 'size'):
    Window.size = (400, 700)

API_URL = "https://wormgpt-api.onrender.com/chat"

class WormChat(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(orientation='vertical', **kwargs)
        self.connected = False
        self.session_id = None

        title = Label(text='[b]WormKit v1.0[/b]', markup=True, size_hint_y=0.06, height=40, color=(0, 1, 0, 1))
        self.add_widget(title)

        scroll = ScrollView()
        self.chat_box = BoxLayout(orientation='vertical', size_hint_y=None, padding=[8, 4])
        self.chat_box.bind(minimum_height=self.chat_box.setter('height'))
        scroll.add_widget(self.chat_box)
        self.add_widget(scroll)

        self.status = Label(text='Unconnected', size_hint_y=0.04, height=28, color=(1, 0, 0, 1))
        self.add_widget(self.status)

        self.connect_btn = Button(text='Connect', size_hint_y=0.07, height=45, background_color=(0.15, 0.6, 0.15, 1), color=(1, 1, 1, 1))
        self.connect_btn.bind(on_press=self.do_connect)
        self.add_widget(self.connect_btn)

        input_row = BoxLayout(size_hint_y=0.09, height=55)
        self.msg_input = TextInput(hint_text='Type a message...', multiline=False, size_hint_x=0.75, background_color=(0.08, 0.08, 0.12, 1), foreground_color=(0, 1, 0, 1), cursor_color=(0, 1, 0, 1))
        self.msg_input.bind(on_text_validate=self.send_msg)
        send_btn = Button(text='Send', size_hint_x=0.25, background_color=(0, 0.7, 0, 1), color=(1, 1, 1, 1))
        send_btn.bind(on_press=self.send_msg)
        input_row.add_widget(self.msg_input)
        input_row.add_widget(send_btn)
        self.add_widget(input_row)

        self.add_msg("WormGPT", "Hello. Press Connect to start.", (0, 1, 0, 1))

    def add_msg(self, sender, text, color=(1, 1, 1, 1)):
        lbl = Label(text=f'[{sender}] {text}', size_hint_y=None, height=45, text_size=(Window.width * 0.75, None), halign='left', valign='middle', color=color, markup=True)
        lbl.bind(texture_size=lbl.setter('size'))
        self.chat_box.add_widget(lbl)

    def do_connect(self, instance):
        self.status.text = 'Connecting...'
        self.status.color = (1, 1, 0, 1)
        threading.Thread(target=self._connect_thread, daemon=True).start()

    def _connect_thread(self):
        try:
            time.sleep(1.2)
            self.connected = True
            Clock.schedule_once(lambda dt: self._on_connected(), 0)
        except Exception as e:
            Clock.schedule_once(lambda dt: self._conn_fail(str(e)), 0)

    def _on_connected(self):
        self.status.text = 'Connected'
        self.status.color = (0, 1, 0, 1)
        self.connect_btn.text = 'Connected'
        self.add_msg("WormGPT", "I am ready. Ask me anything.", (0, 1, 0, 1))

    def _conn_fail(self, err):
        self.status.text = 'Failed'
        self.status.color = (1, 0, 0, 1)
        self.add_msg("Error", str(err), (1, 0.3, 0.3, 1))

    def send_msg(self, instance):
        msg = self.msg_input.text.strip()
        if not msg:
            return
        self.add_msg("You", msg, (0.5, 0.8, 1, 1))
        self.msg_input.text = ''
        if not self.connected:
            self.add_msg("WormGPT", "Connect first!", (1, 0.5, 0, 1))
            return
        self.status.text = 'Thinking...'
        threading.Thread(target=self._response_thread, args=(msg,), daemon=True).start()

    def _response_thread(self, msg):
        try:
            res = requests.post(API_URL, json={"message": msg, "session_id": self.session_id}, timeout=15)
            if res.status_code == 200:
                data = res.json()
                reply = data.get("response", "...")
                self.session_id = data.get("session_id", self.session_id)
            else:
                reply = f"API error: {res.status_code}"
        except:
            reply = "Could not reach API. Server coming soon."
        Clock.schedule_once(lambda dt: self._show_reply(reply), 0)

    def _show_reply(self, reply):
        self.add_msg("WormGPT", reply, (0, 1, 0, 1))
        self.status.text = 'Connected'

class WormKitApp(App):
    def build(self):
        self.title = 'WormKit'
        return WormChat()

if __name__ == '__main__':
    WormKitApp().run()
