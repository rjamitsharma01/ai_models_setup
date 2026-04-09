const socket = io();

let sessionId = null;
let peerId = null;
let rtc = null;
let dc = null;
let scanner = null;

const els = {
  createBtn: document.getElementById('createBtn'),
  joinBtn: document.getElementById('joinBtn'),
  scanBtn: document.getElementById('scanBtn'),
  joinCode: document.getElementById('joinCode'),
  sessionCode: document.getElementById('sessionCode'),
  qrBox: document.getElementById('qrBox'),
  reader: document.getElementById('reader'),
  socketState: document.getElementById('socketState'),
  peerState: document.getElementById('peerState'),
  routeState: document.getElementById('routeState'),
  netHint: document.getElementById('netHint'),
  textInput: document.getElementById('textInput'),
  sendTextBtn: document.getElementById('sendTextBtn'),
  fileInput: document.getElementById('fileInput'),
  sendFileBtn: document.getElementById('sendFileBtn'),
  received: document.getElementById('received')
};

const localCandidates = [];
let remoteCandidates = [];

function setStatus(el, txt) {
  el.textContent = txt;
}

function logReceived(title, html) {
  const div = document.createElement('div');
  div.className = 'item';
  div.innerHTML = `<strong>${title}</strong><br/>${html}`;
  els.received.prepend(div);
}

socket.on('connect', () => setStatus(els.socketState, 'connected'));
socket.on('disconnect', () => setStatus(els.socketState, 'disconnected'));

els.createBtn.addEventListener('click', async () => {
  const res = await fetch('/api/session');
  const data = await res.json();
  sessionId = data.id;
  els.sessionCode.textContent = sessionId;

  const url = `${location.origin}?session=${sessionId}&join=1`;
  els.qrBox.innerHTML = '';
  const canvas = document.createElement('canvas');
  els.qrBox.appendChild(canvas);
  await QRCode.toCanvas(canvas, url, { width: 180 });

  joinSession(sessionId);
});

els.joinBtn.addEventListener('click', () => {
  const code = els.joinCode.value.trim().toUpperCase();
  if (!code) return;
  joinSession(code);
});

els.scanBtn.addEventListener('click', async () => {
  els.reader.classList.remove('hidden');
  if (!scanner) {
    scanner = new Html5Qrcode('reader');
  }
  try {
    await scanner.start(
      { facingMode: 'environment' },
      { fps: 10, qrbox: 220 },
      async (decodedText) => {
        try {
          const url = new URL(decodedText);
          const code = url.searchParams.get('session');
          if (code) {
            els.joinCode.value = code;
            joinSession(code);
            await scanner.stop();
            els.reader.classList.add('hidden');
          }
        } catch (_err) {
          // Ignore non-url QR payload.
        }
      }
    );
  } catch (_err) {
    alert('Unable to access camera for QR scan.');
  }
});

async function joinSession(code) {
  socket.emit('session:join', code, async (resp) => {
    if (!resp?.ok) {
      alert(resp?.error || 'Could not join session');
      return;
    }

    sessionId = code;
    els.sessionCode.textContent = sessionId;
    setStatus(els.peerState, resp.peers.length ? 'peer discovered' : 'waiting for peer');

    if (resp.peers.length) {
      peerId = resp.peers[0];
      await setupRtc(true);
    }
  });
}

socket.on('peer:joined', async (id) => {
  peerId = id;
  setStatus(els.peerState, 'peer connected');
  await setupRtc(false);
});

socket.on('peer:left', () => {
  setStatus(els.peerState, 'peer disconnected');
  setStatus(els.routeState, 'fallback relay only');
  if (rtc) {
    rtc.close();
    rtc = null;
    dc = null;
  }
});

socket.on('signal', async ({ from, data }) => {
  if (!rtc) {
    peerId = from;
    await setupRtc(false);
  }

  if (data.type === 'offer') {
    await rtc.setRemoteDescription(data);
    const answer = await rtc.createAnswer();
    await rtc.setLocalDescription(answer);
    socket.emit('signal', { to: from, data: rtc.localDescription });
  } else if (data.type === 'answer') {
    await rtc.setRemoteDescription(data);
  } else if (data.candidate) {
    await rtc.addIceCandidate(data);
  }
});

async function setupRtc(initiator) {
  rtc = new RTCPeerConnection({
    iceServers: [
      { urls: 'stun:stun.l.google.com:19302' },
      { urls: 'stun:stun1.l.google.com:19302' }
    ]
  });

  localCandidates.length = 0;
  remoteCandidates = [];

  rtc.onicecandidate = (evt) => {
    if (evt.candidate) {
      const ip = extractIp(evt.candidate.candidate);
      if (ip && isPrivateIp(ip)) localCandidates.push(ip);
      socket.emit('signal', { to: peerId, data: evt.candidate });
    }
  };

  rtc.ondatachannel = (event) => {
    dc = event.channel;
    wireDataChannel();
  };

  rtc.onconnectionstatechange = () => {
    if (rtc.connectionState === 'connected') {
      setStatus(els.peerState, 'connected');
      setStatus(els.routeState, 'direct p2p');
      inferNetworkPath();
    } else if (['failed', 'disconnected'].includes(rtc.connectionState)) {
      setStatus(els.routeState, 'fallback relay');
    }
  };

  if (initiator) {
    dc = rtc.createDataChannel('clipboard');
    wireDataChannel();
    const offer = await rtc.createOffer();
    await rtc.setLocalDescription(offer);
    socket.emit('signal', { to: peerId, data: rtc.localDescription });
  }
}

function wireDataChannel() {
  const incomingFiles = new Map();

  dc.onopen = () => {
    setStatus(els.routeState, 'direct p2p');
  };

  dc.onmessage = (event) => {
    const msg = JSON.parse(event.data);

    if (msg.kind === 'text') {
      logReceived('Text', escapeHtml(msg.text));
      navigator.clipboard?.writeText(msg.text).catch(() => {});
      return;
    }

    if (msg.kind === 'file-meta') {
      incomingFiles.set(msg.id, { ...msg, chunks: [], received: 0 });
      return;
    }

    if (msg.kind === 'file-chunk') {
      const state = incomingFiles.get(msg.id);
      if (!state) return;
      state.chunks.push(msg.chunk);
      state.received += 1;
      if (state.received === state.total) {
        const base64 = state.chunks.join('');
        renderFile(state.name, state.type, base64);
        incomingFiles.delete(msg.id);
      }
    }
  };
}

function sendViaBestPath(payload) {
  if (dc && dc.readyState === 'open') {
    dc.send(JSON.stringify(payload));
    return true;
  }
  return false;
}

els.sendTextBtn.addEventListener('click', () => {
  const text = els.textInput.value.trim();
  if (!text || !sessionId) return;

  const sentP2P = sendViaBestPath({ kind: 'text', text });
  if (!sentP2P) {
    socket.emit('relay:text', { sessionId, text });
    setStatus(els.routeState, 'internet relay');
  }
});

els.sendFileBtn.addEventListener('click', async () => {
  const file = els.fileInput.files[0];
  if (!file || !sessionId) return;

  const buffer = await file.arrayBuffer();
  const base64 = arrayBufferToBase64(buffer);
  const sentP2P = sendFileP2P(file, base64);

  if (!sentP2P) {
    socket.emit('relay:file', {
      sessionId,
      file: {
        name: file.name,
        type: file.type || 'application/octet-stream',
        size: file.size,
        payload: base64
      }
    });
    setStatus(els.routeState, 'internet relay');
  }
});

function sendFileP2P(file, base64) {
  if (!dc || dc.readyState !== 'open') return false;

  const id = crypto.randomUUID();
  const chunkSize = 32000;
  const total = Math.ceil(base64.length / chunkSize);
  sendViaBestPath({ kind: 'file-meta', id, name: file.name, type: file.type, total });

  for (let i = 0; i < total; i += 1) {
    const chunk = base64.slice(i * chunkSize, (i + 1) * chunkSize);
    sendViaBestPath({ kind: 'file-chunk', id, chunk, total });
  }

  return true;
}

socket.on('relay:text', ({ text }) => {
  logReceived('Text (relay)', escapeHtml(text));
});

socket.on('relay:file', ({ name, type, payload }) => {
  renderFile(name, type, payload);
});

function renderFile(name, type, base64) {
  const bytes = base64ToUint8(base64);
  const blob = new Blob([bytes], { type: type || 'application/octet-stream' });
  const url = URL.createObjectURL(blob);
  logReceived('File', `<a href="${url}" download="${name}">Download ${escapeHtml(name)}</a>`);
}

function arrayBufferToBase64(buffer) {
  let binary = '';
  const bytes = new Uint8Array(buffer);
  for (let i = 0; i < bytes.byteLength; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function base64ToUint8(base64) {
  const binary = atob(base64);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

function escapeHtml(str) {
  return str
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function extractIp(candidate) {
  if (!candidate) return null;
  const parts = candidate.split(' ');
  const ip = parts[4];
  return ip || null;
}

function isPrivateIp(ip) {
  return /^10\./.test(ip) || /^192\.168\./.test(ip) || /^172\.(1[6-9]|2\d|3[0-1])\./.test(ip);
}

function subnet24(ip) {
  const segments = ip.split('.');
  return segments.length === 4 ? segments.slice(0, 3).join('.') : ip;
}

function inferNetworkPath() {
  const localSubnet = localCandidates.find(Boolean);
  const remoteSubnet = remoteCandidates.find(Boolean);

  if (localSubnet && remoteSubnet && subnet24(localSubnet) === subnet24(remoteSubnet)) {
    setStatus(els.netHint, 'same local network detected (likely same Wi-Fi/hotspot)');
  } else if (localCandidates.length || remoteCandidates.length) {
    setStatus(els.netHint, 'direct path works but subnet differs (might be internet-assisted p2p)');
  } else {
    setStatus(els.netHint, 'unable to confirm local network');
  }
}

socket.on('signal', ({ data }) => {
  if (data?.candidate?.candidate) {
    const ip = extractIp(data.candidate.candidate);
    if (ip && isPrivateIp(ip)) {
      remoteCandidates.push(ip);
    }
  }
});

const params = new URLSearchParams(location.search);
const codeFromUrl = params.get('session');
if (codeFromUrl) {
  els.joinCode.value = codeFromUrl.toUpperCase();
  joinSession(codeFromUrl.toUpperCase());
}
