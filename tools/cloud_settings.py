"""Load and validate public client configuration, never administrator credentials."""
import base64,json,re

def validate(config):
    url=str(config.get('url','')).rstrip('/')
    key=str(config.get('publishableKey',''))
    if not re.fullmatch(r'https://[a-z0-9-]+\.supabase\.co',url):
        raise ValueError('Set SUPABASE_URL to the project HTTPS URL.')
    if re.fullmatch(r'sb_publishable_[A-Za-z0-9_-]+',key) and len(key)>20:
        pass
    elif re.fullmatch(r'[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',key):
        try:
            part=key.split('.')[1]
            role=json.loads(base64.urlsafe_b64decode(part+'='*(-len(part)%4)))['role']
        except Exception:
            raise ValueError('Use a publishable or legacy anon public key.') from None
        if role!='anon':
            raise ValueError('Privileged keys cannot be used in a webpage.')
    else:
        raise ValueError('Set SUPABASE_PUBLISHABLE_KEY to the public client key.')
    return {'url':url,'publishableKey':key}

def read(root):
    path=root/'.garden/cloud-public.json'
    if not path.exists():
        return {'url':'','publishableKey':''}
    return validate(json.loads(path.read_text()))
