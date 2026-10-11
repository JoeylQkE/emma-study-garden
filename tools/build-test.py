"""Bundle an offline testing page; the public page never includes these tools."""
from pathlib import Path
root = Path(__file__).resolve().parent.parent
html = (root / 'index.html').read_text().replace('<title>Emma 的学习花园</title>', '<title>Emma 的学习花园 · 测试版</title>')
html = html.replace('<main>', '<main>\n' + (root / 'tools/test-panel.html').read_text())
html = html.replace('</body>', '<script src="test-controls.js"></script>\n</body>')
for name in ['garden-core.js', 'quotes.js', 'reward-art.js', 'cloud-config.js', 'cloud.js', 'app.js', 'test-controls.js']:
    script = (root / name).read_text()
    if name == 'app.js':
        script = script.replace('const test=false;', 'const test=true;', 1)
    html = html.replace(f'<script src="{name}"></script>', '<script>\n' + script.replace('</script', '<\\/script') + '\n</script>')
(root / 'emma-test.html').write_text(html)
print('Built emma-test.html: standalone test tools, separate from the public site')
