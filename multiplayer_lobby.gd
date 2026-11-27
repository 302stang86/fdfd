extends VBoxContainer

const BROWSER_CLIENT := """

(() => {
  if (window.fieldDayRooms) return;
  const config = {
  apiKey: "AIzaSyAmmAnbo0GlCxIJOeN-UkPUBCvr3bhEcsE",
  authDomain: "castle-world-19db7.firebaseapp.com",
  projectId: "castle-world-19db7",
  storageBucket: "castle-world-19db7.firebasestorage.app",
  messagingSenderId: "732416862128",
  appId: "1:732416862128:web:6f30d8de3a1e6a30981875"
};
  const base = 'https://www.gstatic.com/firebasejs/11.10.0/firebase-';
  const sdk = Promise.all(['app', 'auth', 'firestore'].map(name => import(base + name + '.js')))
    .then(([appSDK, a, f]) => {
      const app = appSDK.initializeApp(config, 'field-day');
      return { a, f, auth: a.getAuth(app), db: f.getFirestore(app) };
    });
  sdk.catch(() => {});
  const state = { busy: false, status: 'Sign in to create or join a room.', email: '', code: '', mode: '', phase: '', guest: false };
  let active = null;
  let unsubscribe = null;
  let expiryTimer = null;
  const modes = ['coop', 'duel', 'ffa'];

  function watch(f, room, code, uid, host) {
    active = { room, uid, host };
    state.code = code;
    state.guest = false;
    unsubscribe = f.onSnapshot(room, snapshot => {
      if (!snapshot.exists()) {
        reset('Room unavailable.');
        return;
      }
      const data = snapshot.data();
      if ((host ? data.hostUid : data.guestUid) !== uid ||
          data.phase === 'closed' || data.expiresAt.toMillis() <= Date.now()) {
        reset('Room closed or expired.');
        return;
      }
      clearTimeout(expiryTimer);
      expiryTimer = setTimeout(() => reset('Room expired.'), Math.max(0, data.expiresAt.toMillis() - Date.now()));
      state.mode = data.mode;
      state.phase = data.phase;
      state.guest = Boolean(data.guestUid);
      state.status = state.guest ? 'Both players are in the room.' : 'Waiting for the second player.';
    }, () => reset('Could not read the room. It may have expired.'));
  }

  function reset(status) {
    clearTimeout(expiryTimer);
    if (unsubscribe) unsubscribe();
    unsubscribe = null;
    active = null;
    Object.assign(state, { code: '', mode: '', phase: '', guest: false, status });
  }

  function roomCode() {
    const values = new Uint32Array(1);
    do crypto.getRandomValues(values); while (values[0] >= 4294000000);
    return String(values[0] % 1000000).padStart(6, '0');
  }

  window.fieldDayRooms = {
    read() { return JSON.stringify(state); },
    async run(action, first, second) {
      if (state.busy) return;
      state.busy = true;
      try {
        const { a, f, auth, db } = await sdk;
        if (action === 'login' || action === 'register') {
          if (!first || !second) throw new Error('Enter an email and password.');
          const handler = action === 'login' ? a.signInWithEmailAndPassword : a.createUserWithEmailAndPassword;
          const result = await handler(auth, first, second);
          state.email = result.user.email;
          state.status = 'Signed in. Create or join a room.';
          return;
        }
        if (!auth.currentUser) throw new Error('Sign in first.');
        const uid = auth.currentUser.uid;
        if (action === 'leave' || action === 'logout') {
          if (active?.host) await f.updateDoc(active.room, { phase: 'closed' }).catch(() => {});
          if (action === 'logout') {
            await a.signOut(auth);
            state.email = '';
          }
          reset(state.email ? 'Left room.' : 'Signed out.');
          return;
        }
        if (active) throw new Error('Leave your current room first.');
        if (action === 'create') {
          if (!modes.includes(first)) throw new Error('Choose a match mode.');
          for (let attempt = 0; attempt < 5; attempt++) {
            const code = roomCode();
            const room = f.doc(db, 'fdfdRooms', code);
            try {
              await f.setDoc(room, {
                session: crypto.randomUUID().replaceAll('-', ''),
                hostUid: uid, guestUid: null, mode: first, phase: 'waiting',
                createdAt: f.serverTimestamp(), expiresAt: f.Timestamp.fromMillis(Date.now() + 25 * 60000)
              });
              watch(f, room, code, uid, true);
              return;
            } catch (error) {
              if (error.code !== 'permission-denied') throw error;
            }
          }
          throw new Error('Could not reserve a room. Try again.');
        }
        if (action === 'join') {
          if (!/^\\d{6}$/.test(first)) throw new Error('Enter a six-digit room code.');
          const room = f.doc(db, 'fdfdRooms', first);
          try {
            await f.updateDoc(room, { guestUid: uid });
          } catch (error) {
            if (!['permission-denied', 'not-found'].includes(error.code)) throw error;
            const retry = await f.getDocFromServer(room).catch(() => null);
            if (!retry?.exists() || retry.data().guestUid !== uid || retry.data().phase !== 'waiting') {
              throw new Error('Room unavailable. Check the code or ask the host for a new room.');
            }
          }
          watch(f, room, first, uid, false);
        }
      } catch (error) {
        const messages = {
          'auth/invalid-credential': 'Email or password is incorrect.',
          'auth/invalid-email': 'Enter a valid email address.',
          'auth/email-already-in-use': 'This email is registered. Use Sign in.',
          'auth/weak-password': 'Use at least six characters for the password.',
          'auth/operation-not-allowed': 'Email sign-in is disabled in Firebase.',
          'auth/network-request-failed': 'Could not reach Firebase.'
        };
        state.status = messages[error.code] || error.message || 'Multiplayer request failed.';
      } finally {
        state.busy = false;
      }
    }
  };

  sdk.then(({ a, auth }) => a.onAuthStateChanged(auth, user => {
    state.email = user?.email || '';
    if (!state.busy && !active) state.status = user ? 'Signed in. Create or join a room.' : 'Sign in to create or join a room.';
  })).catch(() => { state.status = 'Could not load Firebase. Check your connection.'; });
})();
"""

var email: LineEdit
var password: LineEdit
var code: LineEdit
var modes: OptionButton
var status: Label
var sign_in: Button
var register: Button
var sign_out: Button
var create_room: Button
var join_room: Button
var leave: Button
var poll_left := 0.0

func _ready() -> void:
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	if not OS.has_feature("web"):
		status.text = "Online rooms are available in the web build."
		set_process(false)
		return
	JavaScriptBridge.eval(BROWSER_CLIENT, true)
	email = field("Email")
	email.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	password = field("Password")
	password.secret = true
	sign_in = button("Sign in", sign_in_or_register.bind("login"))
	register = button("Register", sign_in_or_register.bind("register"))
	sign_out = button("Sign out", request_room.bind("logout", "", ""))
	modes = OptionButton.new()
	for title in ["Co-op · 2 players vs. 6 bots", "Duel · 1 vs. 1", "Free-for-all · 2 players and 6 bots"]:
		modes.add_item(title)
	add_child(modes)
	create_room = button("Create Room", create_selected_room)
	code = field("Six-digit room code")
	code.max_length = 6
	code.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	join_room = button("Join Room", join_entered_room)
	leave = button("Leave Room", request_room.bind("leave", "", ""))
	update_room_ui()

func field(placeholder: String) -> LineEdit:
	var entry := LineEdit.new()
	entry.placeholder_text = placeholder
	add_child(entry)
	return entry

func button(title: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = title
	control.pressed.connect(callback)
	add_child(control)
	return control

func sign_in_or_register(action: String) -> void:
	request_room(action, email.text.strip_edges(), password.text)
	password.clear()

func create_selected_room() -> void:
	var identifiers := ["coop", "duel", "ffa"]
	request_room("create", identifiers[modes.selected], "")

func join_entered_room() -> void:
	request_room("join", code.text.strip_edges(), "")

func request_room(action: String, first: String, second: String) -> void:
	var client = JavaScriptBridge.get_interface("fieldDayRooms")
	if client != null:
		client.run(action, first, second)
	update_room_ui()

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	poll_left -= delta
	if poll_left <= 0.0:
		poll_left = 0.25
		update_room_ui()

func update_room_ui() -> void:
	var client = JavaScriptBridge.get_interface("fieldDayRooms")
	if client == null:
		status.text = "Could not initialize multiplayer in this browser."
		return
	var state = JSON.parse_string(str(client.read()))
	if not state is Dictionary:
		return
	var signed_in := not String(state.email).is_empty()
	var in_room := not String(state.code).is_empty()
	var busy := bool(state.busy)
	status.text = "Contacting Firebase…" if busy else String(state.status)
	if in_room:
		var labels := {"coop": "Co-op", "duel": "Duel", "ffa": "Free-for-all"}
		status.text = "Room %s · %s · %d/2\n%s\nOnline matches are still in development." % [state.code, labels.get(state.mode, ""), 2 if state.guest else 1, status.text]
	for control in [email, password, sign_in, register]:
		control.visible = not signed_in
	for control in [modes, create_room, code, join_room]:
		control.visible = signed_in and not in_room
	sign_out.visible = signed_in
	leave.visible = signed_in and in_room
	for control in [sign_in, register, sign_out, create_room, join_room, leave]:
		control.disabled = busy
