"""
Cobalt Strike Watermark Fucker By Twi1ight@T00ls.Net

pip install pycryptodome
"""
#!/usr/bin/env python3
import base64
import sys
from Crypto.Cipher import AES

PLACEHOLDER = '123456789abcdefg'


def get_aes_key(a2):
    ss = str(a2)
    a2 = int("%s%s%s%s" % (ss[0], ss[2], ss[-3], ss[-1]))
    a1 = 0x3B9AC990
    a3 = 0x3B9AC9F3
    v3 = a2
    v4 = 1
    v5 = a1 % a3
    while v3 > 0:
        if v3 & 1:
            v4 = v4 * v5 % a3
        v3 >>= 1
        v5 = v5 * v5 % a3
    ret = str(v4)
    for i in range(len(ret), 16):
        ret += PLACEHOLDER[i]
    return ret


def get_plaintext(watermark):
    ret = str(watermark)
    for i in range(len(ret), 16):
        ret += PLACEHOLDER[i]
    return ret


if __name__ == '__main__':
    print('Cobalt Strike Watermark Fucker By Twi1ight@T00ls.Net')
    if len(sys.argv) != 2:
        exit(f"Usage: python3 watermark.py watermark_number")
    assert sys.argv[1].isdigit(), 'invalid watermark!'
    watermark = int(sys.argv[1])
    assert watermark >= 0x270, 'watermark must >= 0x270'
    key = get_aes_key(watermark)
    plaintext = get_plaintext(watermark)
    cipher = AES.new(key.encode(), AES.MODE_CBC, IV=b'abcdefghijklmnop')
    ciphertext = cipher.encrypt(plaintext.encode())
    print('watermark:', watermark)
    print('watermarkHash:', base64.b64encode(ciphertext).decode())
