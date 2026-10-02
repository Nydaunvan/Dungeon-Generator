"""Aller-retour DGZ1 avec le HTML d'origine (Chromium/Playwright).
Usage : python3 tools/code_roundtrip.py gen <dir> <html>   puis, après le test Godot : python3 tools/code_roundtrip.py check <dir> <html>"""
import asyncio, sys, json
from playwright.async_api import async_playwright
mode, d, html = sys.argv[1], sys.argv[2], sys.argv[3]
async def main():
    async with async_playwright() as p:
        b = await p.chromium.launch(executable_path='/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args=['--no-sandbox'])
        pg = await b.new_page()
        await pg.route('**/*', lambda r: r.abort() if r.request.url.startswith('http') else r.continue_())
        await pg.goto('file://' + html)
        await pg.wait_for_timeout(3000)
        if mode == 'gen':
            code = await pg.evaluate("encodeConfigToCode(CONFIG)")
            cfg = await pg.evaluate("JSON.stringify(CONFIG)")
            open(d + '/html_code.txt', 'w').write(code)
            open(d + '/html_cfg.json', 'w').write(cfg)
            print('HTML code', len(code))
        else:
            code = open(d + '/go_code.txt').read()
            want = json.loads(open(d + '/go_cfg.json').read())
            got = await pg.evaluate("c=>decodeConfigFromCode(c)", code)
            print('Godot -> HTML :', 'OK' if got == want else 'FAIL')
        await b.close()
asyncio.run(main())
