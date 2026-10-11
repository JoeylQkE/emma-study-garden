"""Persist public Supabase configuration outside tracked application files."""
from pathlib import Path
import os,json
from cloud_settings import validate
root=Path(__file__).resolve().parent.parent
try:
    config=validate({'url':os.environ.get('SUPABASE_URL',''),'publishableKey':os.environ.get('SUPABASE_PUBLISHABLE_KEY','')})
except ValueError as error:
    raise SystemExit(str(error)) from None
out=root/'.garden/cloud-public.json'
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps(config,ensure_ascii=True)+'\n')
print('Saved public client configuration for',config['url'].split('://',1)[1])
print('Next: python3 tools/publish-pages.py after creating the database and linking the accounts.')
