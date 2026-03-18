import base64

def encode_server_url(url, password="ABCD"):
    # 1. Perform XOR
    url_bytes = url.encode('ascii')
    pass_bytes = password.encode('ascii')
    
    xor_bytes = bytearray()
    for i in range(len(url_bytes)):
        xor_byte = url_bytes[i] ^ pass_bytes[i % len(pass_bytes)]
        xor_bytes.append(xor_byte)
    
    # 2. Base64 Encode
    return base64.b64encode(xor_bytes).decode('ascii')

if __name__ == "__main__":
    print("--- FNFast Discovery Encoder ---")
    my_url = input("Enter your Server URL (e.g. http://1.2.3.4:8000): ")
    encoded = encode_server_url(my_url)
    print("\n[!] UPLOAD THIS STRING TO YOUR BOOTSTRAP URL:")
    print(f"\n{encoded}\n")