def simple_decrypt(encrypted_string):
    decrypted_string = ""
    for char in encrypted_string:
        if char == 'd':
            decrypted_string += '-'
        elif char.isdigit():
            decrypted_digit = (int(char) - 3 + 10) % 10
            decrypted_string += str(decrypted_digit)
        else:
            # Handle other characters if necessary
            decrypted_string += char
    return decrypted_string

# Example usage:
# Replace with the actual encrypted string from the QR code
encrypted_string_from_qr = '321d321d321' 
decrypted_account_number = simple_decrypt(encrypted_string_from_qr)
print(f"Decrypted Account Number: {decrypted_account_number}")