import socket, struct, sys

def read_pkt(s):
    hdr = b''
    while len(hdr) < 4: hdr += s.recv(4 - len(hdr))
    ln = hdr[0] | hdr[1] << 8 | hdr[2] << 16
    seq = hdr[3]
    payload = b''
    while len(payload) < ln: payload += s.recv(ln - len(payload))
    return seq, payload

def send_pkt(s, seq, payload):
    s.sendall(struct.pack('<I', len(payload))[:3] + bytes([seq]) + payload)

def handshake(user, plugin, auth_payload):
    s = socket.create_connection(('127.0.0.1', 4100), timeout=5)
    seq, p = read_pkt(s)
    assert p[0] == 10, f'unexpected initial packet {p[0]}'
    # server capabilities at p[2:4] (lower), salt at p[4:4+20]
    caps = struct.unpack('<H', p[2:4])[0]
    # HandshakeResponse41
    client_caps = 0x1 | 0x200 | 0x8000 | 0x80000 # LONG_PASSWORD|PROTOCOL_41|SECURE_CONNECTION|PLUGIN_AUTH
    pkt = struct.pack('<I', client_caps)
    pkt += struct.pack('<I', 16777216)
    pkt += bytes([33]) # charset utf8_general_ci... actually 33=utf8
    pkt += b'\x00' * 23
    pkt += user.encode() + b'\x00'
    pkt += bytes([len(auth_payload)]) + auth_payload
    pkt += plugin.encode() + b'\x00'
    send_pkt(s, seq + 1, pkt)
    seq, resp = read_pkt(s)
    result = 'OK' if resp[0] == 0x00 else ('ERR: ' + resp[1:3].hex() + ' ' + resp[13:].decode(errors='replace') if resp[0] == 0xFF else f'other:{resp[0]:02x} {resp[:60]!r}')
    s.close()
    return result

if __name__ == '__main__':
    user, plugin, tokfile = sys.argv[1], sys.argv[2], sys.argv[3]
    token = open(tokfile).read().strip().encode()
    print(handshake(user, plugin, token))
