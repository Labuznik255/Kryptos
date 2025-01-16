import sys
import os


old_fn = "words_alpha.txt"
new_fn = "words_beta.txt"
treshold_min = 3
treshold_max = 8

if(len(sys.argv) > 1):
    treshold_min = int(sys.argv[1])
if(len(sys.argv) > 2):
    treshold_max = int(sys.argv[2])
if(len(sys.argv) > 3):
    old_fn = sys.argv[3]
if(len(sys.argv) > 4):
    new_fn = sys.argv[4]

if os.path.exists("words_beta.txt"):
    os.remove("words_beta.txt")

if os.path.exists(old_fn):
    old = open(old_fn, "r")
else:
    print("file " + old_fn + " not found")
    exit()

new = open(new_fn, "w")

count = 0

for line in old:
    line.strip()
    
    result = ''.join(filter(str.isalpha, line))
    result = result.lower()

    if(len(result) >= treshold_min and len(result) <= treshold_max):
        new.write(result + "\n")
        count += 1

print(count)

old.close()
new.close()
