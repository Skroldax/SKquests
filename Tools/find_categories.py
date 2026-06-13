import urllib.request
import re

url = 'https://classicdb.ch/templates/wowhead/js/locale_enus.js'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla'})
data = urllib.request.urlopen(req).read().decode('utf-8')

import sys
sys.stdout.reconfigure(encoding='utf-8')

match = re.search(r'var mn_quests\s*=\s*\[(.*?)\];', data, re.DOTALL)
if match:
    print(match.group(1)[:1000])
else:
    print("Not found")
    with open("locale_enus.js", "w", encoding="utf-8") as f:
        f.write(data)
