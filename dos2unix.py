import os
# replacement strings
WINDOWS_LINE_ENDING = b'\r\n'
UNIX_LINE_ENDING = b'\n'

# relative or absolute file path, e.g.:
file_path = r"/uLogR/src/tests/ref/decoder_test.ref"
dir = os.path.dirname(__file__)
filename = os.path.join(dir, file_path)

with open(file_path, 'rb') as open_file:
    content = open_file.read()

content = content.replace(WINDOWS_LINE_ENDING, UNIX_LINE_ENDING)

with open(file_path, 'wb') as open_file:
    open_file.write(content)
