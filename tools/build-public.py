"""Build only the public runtime. Does not ship laboratory files or URLs."""
from pathlib import Path
import zipfile,json
from cloud_settings import read
root = Path(__file__).resolve().parent.parent
html = (root / 'index.html').read_text()
for name in ['garden-core.js', 'quotes.js', 'reward-art.js', 'cloud-config.js', 'cloud.js', 'app.js']:
    script = (root / name).read_text()
    if name == 'cloud-config.js':
        script = 'window.GARDEN_CLOUD_CONFIG='+json.dumps(read(root))+';'
    html = html.replace(f'<script src="{name}"></script>', '<script>\n' + script.replace('</script', '<\\/script') + '\n</script>')
for marker in ['id="testPanel"', 'id="toggleMode"', 'test-controls.js', 'GARDEN_TEST', "mode')", 'Joyce']:
    assert marker not in html, f'Public build contains unexpected marker: {marker}'
out = root / 'public'
out.mkdir(exist_ok=True)
(out / 'index.html').write_text(html)
(out / '.nojekyll').touch()
(root / 'emma-public.html').write_text(html)
with zipfile.ZipFile(root / 'emma-public.zip', 'w', compression=zipfile.ZIP_DEFLATED) as z:
    z.write(out / 'index.html', 'index.html')
    z.write(out / '.nojekyll', '.nojekyll')
print('Built public/index.html, emma-public.html and emma-public.zip; no test controls included')
