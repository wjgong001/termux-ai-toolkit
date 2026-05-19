#!/usr/bin/env python3
"""Scan all non-closed markets on Polymarket for sports/politics with viable CLOB depth."""

import os, json, urllib.request, hashlib, hmac, base64, time

API_KEY = "a758d055-2d44-0370-2302-da70a66e2142"
API_SECRET = "8uh_9g0TWpkUNBZBb1Kt91aZa7C9L57H_a8xLnz1abc="
API_PASSPHRASE = "000d79e3fa3df420298a0751112590571caa70767af205c39d3bf1c73a9d3a50"

def api_get(url, signed=False):
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "Mozilla/5.0")
    if signed and API_KEY:
        ts = str(int(time.time() * 1000))
        method = "GET"
        # path without query string
        path = url.split("?")[0].replace("https://clob.polymarket.com", "")
        msg = ts + method + path
        secret_bytes = base64.b64decode(API_SECRET)
        sig = base64.b64encode(hmac.new(secret_bytes, msg.encode(), hashlib.sha256).digest()).decode()
        req.add_header("POLY_ADDRESS", API_KEY)
        req.add_header("POLY_SIGNATURE", sig)
        req.add_header("POLY_TIMESTAMP", ts)
        req.add_header("POLY_NONCE", ts)
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read())

def get_orderbook(token_id):
    """Get CLOB orderbook for a token."""
    try:
        url = f"https://clob.polymarket.com/orderbook?token_id={token_id}&side=BUY"
        data = api_get(url, signed=True)
        return data
    except Exception as e:
        return {"error": str(e)}

print("=" * 80)
print("SCANNING SPORTS + POLITICS MARKETS WITH CLOB DEPTH")
print("=" * 80)

categories = ["sports", "politics"]
seen_markets = set()

for cat in categories:
    print(f"\n{'='*60}")
    print(f"CATEGORY: {cat.upper()}")
    print(f"{'='*60}")
    
    # Get events
    events = api_get(f"https://gamma-api.polymarket.com/events?tag={cat}&closed=false&limit=100")
    print(f"  Events found: {len(events)}")
    
    for ev in events:
        title = ev.get("title", "")[:60]
        ev_id = ev["id"]
        ev_vol = ev.get("volume", "0")
        
        # Get markets for this event
        markets = api_get(f"https://gamma-api.polymarket.com/markets?event_id={ev_id}&limit=20")
        
        for m in markets:
            token_id = m.get("tokenId", "")
            if not token_id or token_id in seen_markets:
                continue
            seen_markets.add(token_id)
            
            question = m.get("question", "")[:50]
            outcome = m.get("outcome", "")[:30]
            
            # Check CLOB midpoint + depth
            try:
                mp_url = f"https://clob.polymarket.com/midpoints?token_id={token_id}"
                mp = api_get(mp_url, signed=True)
                midpoint = mp.get("midpoint", "N/A")
            except:
                midpoint = "N/A"
            
            # Check full orderbook for BUY side
            ob = get_orderbook(token_id)
            if isinstance(ob, dict) and "bids" in ob:
                bids = ob.get("bids", [])
                asks = ob.get("asks", [])
            else:
                bids = []
                asks = []
            
            n_bids = len(bids) if isinstance(bids, list) else 0
            n_asks = len(asks) if isinstance(asks, list) else 0
            
            # Check if any orders exist and within 50 USDC budget
            cheapest = None
            if isinstance(asks, list) and len(asks) > 0:
                try:
                    cheapest = min((float(a.get("price", 999)) for a in asks if a.get("price")), default=None)
                except:
                    pass
            richest = None
            if isinstance(bids, list) and len(bids) > 0:
                try:
                    richest = max((float(b.get("price", 0)) for b in bids if b.get("price")), default=None)
                except:
                    pass
            
            min_size = None
            if isinstance(asks, list) and len(asks) > 0:
                try:
                    # First ask size
                    min_size = float(asks[0].get("size", 0)) if asks[0].get("size") else None
                except:
                    pass
            
            print(f"\n  {question}")
            print(f"    token_id={token_id[:30]}... | outcome={outcome} | midpoint={midpoint}")
            print(f"    bids={n_bids} orders | asks={n_asks} orders | cheapest ask=${cheapest} | richest bid=${richest}")
            if cheapest and min_size:
                cost_per_share = cheapest
                if cost_per_share * min_size <= 50:
                    print(f"    *** VIABLE: {min_size} shares @ ${cost_per_share} = ${cost_per_share*min_size:.2f} total ***")

print(f"\n{'='*60}")
print(f"Total unique markets scanned: {len(seen_markets)}")
print(f"{'='*60}")
