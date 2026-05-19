#!/usr/bin/env python3
"""Scan CLOB markets for any viable 50-USDC-sized bets."""

import os, json, urllib.request, hashlib, hmac, base64, time

API_KEY = "a758d055-2d44-0370-2302-da70a66e2142"
API_SECRET = "8uh_9g0TWpkUNBZBb1Kt91aZa7C9L57H_a8xLnz1abc="
API_PASSPHRASE = "000d79e3fa3df420298a0751112590571caa70767af205c39d3bf1c73a9d3a50"
CLOB = "https://clob.polymarket.com"

def b64url_decode(s):
    """Decode URL-safe base64. Polymarket secret has url-safe chars (_, -) but uses '=' padding."""
    # Polymarket secret is standard base64 (with + and /), not url-safe
    # The issue: 41 chars is not valid base64 (not multiple of 4)
    # Add padding to make it valid
    # Replace url-safe chars with standard base64 chars before decoding
    s = s.strip().replace("-", "+").replace("_", "/")
    padding = 4 - len(s) % 4
    if padding != 4:
        s += "=" * padding
    return base64.b64decode(s)

def api_get(url, signed=False):
    req = urllib.request.Request(url)
    req.add_header("User-Agent", "Mozilla/5.0")
    if signed and API_KEY:
        ts = str(int(time.time() * 1000))
        method = "GET"
        path = url.split("?")[0].replace(CLOB, "")
        msg = ts + method + path
        secret_bytes = b64url_decode(API_SECRET)
        sig = base64.b64encode(hmac.new(secret_bytes, msg.encode(), hashlib.sha256).digest()).decode()
        req.add_header("POLY_ADDRESS", API_KEY)
        req.add_header("POLY_SIGNATURE", sig)
        req.add_header("POLY_TIMESTAMP", ts)
        req.add_header("POLY_NONCE", ts)
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read())
    except Exception as e:
        return {"_error": str(e)}

# Step 1: Get all CLOB markets accepting orders
print("=== Step 1: CLOB markets accepting orders ===")
markets = api_get(f"{CLOB}/markets?limit=500", signed=True)
if isinstance(markets, dict) and markets.get("_error"):
    print(f"ERROR: {markets['_error']}")
else:
    # `/markets` might return list directly or nested
    if isinstance(markets, list):
        mlist = markets
    elif isinstance(markets, dict) and "data" in markets:
        mlist = markets["data"]
    else:
        mlist = [markets] if markets else []
    
    print(f"  Found {len(mlist)} markets\n")
    
    viable = []
    for i, m in enumerate(mlist):
        if not isinstance(m, dict):
            continue
        cond_id = m.get("condition_id") or m.get("conditionId") or m.get("id","")
        token_id = m.get("token_id") or m.get("tokenId") or ""
        
        # Get market info to find what it's about
        q = m.get("question", m.get("title", ""))[:60]
        outcome = m.get("outcome", m.get("name", ""))[:30]
        
        # Get orderbook
        try:
            ob = api_get(f"{CLOB}/orderbook?token_id={token_id}&side=BUY", signed=True)
        except:
            ob = {}
        
        bids = ob.get("bids", []) if isinstance(ob, dict) else []
        asks = ob.get("asks", []) if isinstance(ob, dict) else []
        
        n_bids = len(bids) if isinstance(bids, list) else 0
        n_asks = len(asks) if isinstance(asks, list) else 0
        
        # Check cheapest ask
        cheapest_ask = None
        cheapest_ask_size = None
        if isinstance(asks, list) and len(asks) > 0:
            try:
                valid = [(float(a["price"]), float(a.get("size", 0))) for a in asks if a.get("price")]
                if valid:
                    cheapest_ask = min(v[0] for v in valid)
                    # find size at that price
                    for p, s in valid:
                        if p == cheapest_ask:
                            cheapest_ask_size = s
                            break
            except:
                pass
        
        richest_bid = None
        if isinstance(bids, list) and len(bids) > 0:
            try:
                valid = [(float(b["price"]), float(b.get("size", 0))) for b in bids if b.get("price")]
                if valid:
                    richest_bid = max(v[0] for v in valid)
            except:
                pass
        
        print(f"[{i+1:3d}] {q}")
        print(f"      outcome={outcome} | asks={n_asks} | bids={n_bids}")
        print(f"      cheapest=@{cheapest_ask} (size={cheapest_ask_size}) | best_bid=${richest_bid}")
        
        if cheapest_ask is not None and cheapest_ask_size is not None:
            cost = cheapest_ask * cheapest_ask_size
            if cost <= 50:
                print(f"      *** VIABLE: {cheapest_ask_size} shares @ ${cheapest_ask} = ${cost:.2f} ***")
                viable.append((q, token_id, cheapest_ask, cheapest_ask_size, cost))
        
        print()
        if i >= 100:
            print("  ... more markets omitted for brevity")
            break
    
    print(f"\n=== VIABLE MARKETS (cost <= 50 USDC) ===")
    if viable:
        for q, tk, price, size, cost in viable:
            print(f"  {q}: {size} @ ${price} = ${cost:.2f} (token_id={tk[:30]}...)")
    else:
        print("  None found — no market has ask price × min size ≤ 50 USDC")
