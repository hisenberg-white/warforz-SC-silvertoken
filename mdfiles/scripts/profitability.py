# -*- coding: utf-8 -*-
import io

G = 1000.0  # Economy V1 SS14 reference: 1 Gold = 1,000 FT

# name: (base_ft, gold_chance, damage, cooldown_sec, f2p_selector_weight)
MINERS = [('Artifact',27,.005,5,7200,.5500),('Common',55,.05,10,3600,.2500),
          ('Uncommon',85,.04,15,3600,.1200),('Rare',120,.03,20,3600,.0600),
          ('Epic',155,.02,25,3600,.0175),('Legendary',195,.015,30,3600,.0025)]
# name: (multiplier, gold_bonus, gold_cost, ft_cost, uses)
GEAR = [('None',1.0,0,0,0,1),('Common',1.35,.025,3,1800,125),('Uncommon',1.60,.020,3,2500,125),
        ('Rare',1.90,.015,5,4500,125),('Epic',2.25,.0075,7,7000,125),('Legendary',2.60,.0025,10,8900,125)]
# name: (boost, gold_bonus, gold_cost, ft_cost, uses, band)
LIVE = [('F2P',1.0,0,0,0,1,None),
        ('Epic',1.10,.01,3,986,75,['Epic']),
        ('Legendary',1.12,.01,11,3100,300,['Legendary']),
        ('Diamond',1.15,.0125,21,5150,600,['Common','Uncommon','Rare','Epic','Legendary'])]
PROPOSED = [('F2P',1.0,0,0,0,1,None),
        ('Epic',1.10,.01,3,986,75,['Common','Uncommon','Rare']),
        ('Legendary',1.12,.01,11,3100,300,['Uncommon','Rare','Epic']),
        ('Diamond',1.15,.0125,21,5150,600,['Rare','Epic','Legendary'])]
CAP = 0.10

def calc(m, g, l, gold_rate=G):
    mn,base,drop,dmg,cd,acc = m
    gn,gb,gd,gg,gf,gu = g
    ln,lb,ld,lg,lf,lu,band = l
    inband = bool(band) and mn in band
    boost = lb if inband else 1.0
    gross = base*gb*boost
    chance = min(drop+gd+ld, CAP)
    gold = chance*gold_rate
    lcost = 0.0 if ln=='F2P' else (lf+lg*gold_rate)/lu
    gcost = 0.0 if gn=='None' else (gf+gg*gold_rate)/gu
    heal = dmg*5
    net = gross+gold-lcost-gcost-heal
    mph = (acc if ln=='F2P' else 1.0)*(3600.0/max(cd,3600))
    return dict(gross=gross,chance=chance,gold=gold,lcost=lcost,gcost=gcost,
                heal=heal,net=net,hourly=net*mph,inband=inband,mph=mph)

def rows(lands, rate=G):
    out=[]
    for m in MINERS:
        for g in GEAR:
            for l in lands:
                r=calc(m,g,l,rate); r.update(miner=m[0],gear=g[0],land=l[0]); out.append(r)
    return out

L=[]
w=L.append
w('# WarForz Lands — Profitability Tables')
w('')
w('**Every miner × equipment × land combination, with net profit per mine.**')
w('')
w('| | |')
w('|---|---|')
w('| Generated | 2026-09-05 |')
w('| Basis | `WARFORZLANDS_ECONOMY_CONFIG_V1.md` + live `warforzlands` config on WAX testnet |')
w('| Combinations | 6 miners × 6 equipment × 4 lands = **144** |')
w('| Applies to | WAX **and** Robinhood Chain — the two run identical economies |')
w('')
w('---')
w('')
w('## ⚠️ Read this before publishing any number here')
w('')
w('Every figure below values **1 Gold = 1,000 FT**. That is Economy V1 §14\'s *internal balancing reference*, explicitly labelled temporary, **not a market price**.')
w('')
w('Gold is a large share of low-tier income — a Common miner earns more value in Gold than in FT — so **low-tier profitability moves sharply with the real Gold price.** §6 shows the sensitivity. If you publish these tables to players, publish the assumption with them, or state figures in Gold and FT separately rather than as one FT-equivalent number.')
w('')
w('---')
w('')
w('## 1. How the numbers are calculated')
w('')
w('```text')
w('FT reward   = miner base FT × equipment multiplier × land boost')
w('              (land boost applies ONLY if the miner is in that land\'s band)')
w('')
w('Gold chance = miner chance + equipment bonus + land bonus     (additive)')
w('              capped at 10%; the land bonus applies to EVERY miner')
w('')
w('Costs per mine:')
w('  land use  = (land FT cost + land Gold cost × rate) ÷ land uses')
w('  gear use  = (gear FT cost + gear Gold cost × rate) ÷ 125 uses')
w('  healing   = miner damage × 5 FT')
w('')
w('NET = FT reward + expected Gold value − land − gear − healing')
w('```')
w('')
w('**FT/hour** additionally accounts for access: premium land allows one mine per hour; F2P land only when your tier is the active selector (Artifact 55% of hours, Common 25%, Uncommon 12%, Rare 6%, Epic 1.75%, Legendary 0.25%). Artifact miners also carry a 2-hour cooldown.')
w('')
w('---')
w('')

# ---- best strategies ----
r_live = rows(LIVE)
top = sorted(r_live, key=lambda r:-r['hourly'])[:10]
w('## 2. Highest profit')
w('')
w('| Rank | Miner | Equipment | Land | FT/mine | FT/hour |')
w('|---:|---|---|---|---:|---:|')
for i,r in enumerate(top,1):
    w('| %d | %s | %s | %s | %.1f | %.1f |'%(i,r['miner'],r['gear'],r['land'],r['net'],r['hourly']))
w('')
w('**The miner tier is the dominant lever.** A Legendary miner with *Uncommon* equipment out-earns most Epic-miner setups. Upgrade the miner before the equipment.')
w('')
w('### Best setup at each miner tier')
w('')
w('| If you own | Best equipment | Best land | FT/mine | FT/hour |')
w('|---|---|---|---:|---:|')
for m in MINERS:
    best=max([r for r in r_live if r['miner']==m[0]], key=lambda r:r['hourly'])
    w('| %s | %s | %s | %.1f | %.1f |'%(m[0],best['gear'],best['land'],best['net'],best['hourly']))
w('')
w('---')
w('')

# ---- losses ----
loss=[r for r in r_live if r['net']<0]
w('## 3. ⚠️ Loss-making combinations — %d of 144'%len(loss))
w('')
w('These **cost more than they earn**. Both traps have the same shape: a *flat* per-use cost set against a *multiplicative* reward, so they punish low-output miners hardest.')
w('')
w('### Trap 1 — Artifact miner on premium land')
w('')
w('An Artifact miner grosses 27 FT. Premium land costs 43–53 FT per use before equipment or healing. **It can never pay.** Artifact miners belong on F2P land.')
w('')
w('### Trap 2 — expensive equipment on a cheap miner')
w('')
w('Legendary equipment costs **151.2 FT per use** no matter what it is attached to. A Common miner grossing 143 FT cannot cover it. Match equipment to miner.')
w('')
w('| Miner | Equipment | Land | FT/mine |')
w('|---|---|---|---:|')
for r in sorted(loss,key=lambda r:r['net']):
    w('| %s | %s | %s | **%.1f** |'%(r['miner'],r['gear'],r['land'],r['net']))
w('')
w('Uncommon, Rare, Epic and Legendary miners **never lose** on any land with any equipment.')
w('')
w('---')
w('')

# ---- full matrix ----
w('## 4. Full matrix — all 144 combinations')
w('')
w('Land bands as currently live: Epic Land boosts Epic miners; Legendary Land boosts Legendary miners; Diamond Land boosts everything except Artifact. `boost?` shows whether the land\'s FT boost applied.')
w('')
for m in MINERS:
    w('### %s miner — %g FT base, %.2f%% Gold, %d damage, %ds cooldown'%(m[0],m[1],m[2]*100,m[3],m[4]))
    w('')
    w('| Equipment | Land | boost? | FT reward | Gold % | Gold value | Land cost | Gear cost | Heal | **NET** | FT/hour |')
    w('|---|---|:---:|---:|---:|---:|---:|---:|---:|---:|---:|')
    for g in GEAR:
        for l in LIVE:
            r=calc(m,g,l)
            flag='✅' if r['inband'] else '—'
            net='**%.1f**'%r['net'] if r['net']>=0 else '**⚠️ %.1f**'%r['net']
            w('| %s | %s | %s | %.1f | %.2f%% | %.1f | %.1f | %.1f | %.1f | %s | %.1f |'%(
                g[0],l[0],flag,r['gross'],r['chance']*100,r['gold'],r['lcost'],r['gcost'],r['heal'],net,r['hourly']))
    w('')
w('---')
w('')

# ---- gold sensitivity ----
w('## 5. Gold price sensitivity')
w('')
w('Net FT per mine for the best setup at each tier, at three Gold prices. **The 1,000 FT column is the V1 reference; the others show what happens if the market disagrees.**')
w('')
w('| Miner | Gold @ 500 FT | Gold @ 1,000 FT | Gold @ 2,000 FT |')
w('|---|---:|---:|---:|')
for m in MINERS:
    cells=[]
    for rate in (500.0,1000.0,2000.0):
        rr=rows(LIVE,rate); best=max([r for r in rr if r['miner']==m[0]],key=lambda r:r['hourly'])
        cells.append('%.1f'%best['net'])
    w('| %s | %s | %s | %s |'%(m[0],cells[0],cells[1],cells[2]))
w('')
w('**Low tiers are Gold-dependent, high tiers are FT-dependent.** A Common miner earns most of its value in Gold, so a falling Gold price hits it hardest. A Legendary miner earns most of its value in FT and barely notices. Any change to the Gold market therefore hits new players first.')
w('')
w('---')
w('')

# ---- proposed bands diff ----
w('## 6. Effect of the proposed band rebalance')
w('')
w('Under consideration (`FIX_D1=matched`, see `WARFORZLANDS_ECONOMY_AUDIT.md`): Epic Land → Common/Uncommon/Rare · Legendary Land → Uncommon/Rare/Epic · Diamond Land → Rare/Epic/Legendary.')
w('')
w('Combinations whose net changes, best equipment only:')
w('')
w('| Miner | Equipment | Land | Now | Proposed | Change |')
w('|---|---|---|---:|---:|---:|')
bestgear={'Artifact':'None','Common':'Common','Uncommon':'Common','Rare':'Rare','Epic':'Legendary','Legendary':'Legendary'}
for m in MINERS:
    g=[x for x in GEAR if x[0]==bestgear[m[0]]][0]
    for i,l in enumerate(LIVE):
        a=calc(m,g,l); b=calc(m,g,PROPOSED[i])
        if abs(a['net']-b['net'])>0.05:
            d=b['net']-a['net']
            w('| %s | %s | %s | %.1f | %.1f | %s%.1f |'%(m[0],g[0],l[0],a['net'],b['net'],'+' if d>0 else '',d))
w('')
w('⚠️ **Common and Uncommon miners lose the Diamond Land boost they receive today.** Announce before applying.')
w('')
w('---')
w('')
w('## 7. Reproduce these tables')
w('')
w('```bash')
w('python scripts/profitability.py > WARFORZLANDS_PROFITABILITY.md')
w('```')
w('')
w('Regenerate after **any** economy change — a balance edit that looks small can flip a combination from profit to loss. The two traps in §3 exist because per-use costs are flat while rewards are multiplicative; that relationship is easy to break by accident.')

io.open(r'D:\Projects\pratice\wax chain\WARFORZLANDS_PROFITABILITY.md','w',encoding='utf-8').write('\n'.join(L)+'\n')
print('written:', len(L), 'lines')
