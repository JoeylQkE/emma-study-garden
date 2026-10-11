"""Publish public/ to gh-pages without staging or changing the working branch."""
from pathlib import Path
import os
import subprocess
import tempfile
root = Path(__file__).resolve().parent.parent

def git(*args, env=None, data=None):
    return subprocess.check_output(['git', '-C', str(root), *args], env=env, input=data, text=True).strip()

subprocess.run(['python3', str(root / 'tools/build-public.py')], check=True)
remote = git('ls-remote', 'origin', 'refs/heads/gh-pages')
if remote:
    subprocess.run(['git', '-C', str(root), 'fetch', '--no-tags', 'origin', 'refs/heads/gh-pages'], check=True)
    parent = git('rev-parse', 'FETCH_HEAD')
    files = set(git('ls-tree', '-r', '--name-only', parent).splitlines())
    if not files <= {'index.html', '.nojekyll'}:
        raise SystemExit('Existing gh-pages has other files; preserve and review them before publishing.')
else:
    parent = git('rev-parse', 'HEAD')
with tempfile.TemporaryDirectory(prefix='emma-pages-') as temp:
    release_env = dict(os.environ, GIT_INDEX_FILE=str(Path(temp) / 'index'))
    git('read-tree', '--empty', env=release_env)
    for name in ['index.html', '.nojekyll']:
        blob = git('hash-object', '-w', str(root / 'public' / name))
        git('update-index', '--add', '--cacheinfo', '100644', blob, name, env=release_env)
    tree = git('write-tree', env=release_env)
    commit = git('-c', 'user.name=Codex', '-c', 'user.email=codex@users.noreply.github.com', 'commit-tree', tree, '-p', parent, data='Publish Emma learning garden with cloud login and shared records support\n')
    subprocess.run(['git', '-C', str(root), 'push', 'origin', f'{commit}:refs/heads/gh-pages'], check=True)
    verified = git('ls-remote', 'origin', 'refs/heads/gh-pages').split()[0]
    if verified != commit:
        raise SystemExit('Remote branch did not match the published commit.')
    print('Published and verified gh-pages:', commit)
    print('Published files: index.html, .nojekyll. Working branch and index preserved.')
