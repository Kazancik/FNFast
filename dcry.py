import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from matplotlib.widgets import Button
import collections

# -------------------------
# Ayarlar (Fizik Parametreleri)
# -------------------------
GUCLU_CEKIM, GUCLU_ITIM = 450.0, 550.0
COULOMB_K = 80.0
BAG_MESAFESI = 4.5
DT, SURTUNME = 0.02, 0.88
KUTLE_NUKLEON, KUTLE_ELEKTRON = 1.0, 0.05

ELEMENTLER = {
    0: "Nötron Kümesi", 1: "Hidrojen (H)", 2: "Helyum (He)", 3: "Lityum (Li)", 
    4: "Berilyum (Be)", 5: "Bor (B)", 6: "Karbon (C)", 7: "Azot (N)", 
    8: "Oksijen (O)", 9: "Flor (F)", 10: "Neon (Ne)"
}

parcaciklar = []
secili_mod = 'p'
duraklatildi = False

class Parcacik:
    def __init__(self, pos, p_tip):
        self.pos = np.array(pos, dtype=float)
        self.vel = np.array([0.0, 0.0])
        self.tip = p_tip  
        self.yuk = 1 if p_tip == 'p' else (-1 if p_tip == 'e' else 0)
        
        # Değişken ismini 'mass' yaparak hata riskini kaldırdık
        self.mass = KUTLE_ELEKTRON if p_tip == 'e' else KUTLE_NUKLEON
        
        # Görünüm (TAM DOLU)
        self.renk = {'p': '#FF3333', 'n': '#3333FF', 'e': '#00FFFF'}[p_tip]
        self.boyut = 40 if p_tip == 'e' else 160

# -------------------------
# Kararlılık ve AI Analizi
# -------------------------
def kararlilik_analizi(z, n):
    if z == 0 and n > 0: return "⚠ KARARSIZ (Saf Nötron)"
    if z == 1 and n == 0: return "✅ KARARLI (Hidrojen)"
    if z == 1 and n == 1: return "✅ KARARLI (Ağır Hidrojen)"
    if z == 2 and n == 2: return "✅ KARARLI (Helyum)"
    if z > 0:
        oran = n / z
        if 0.75 <= oran <= 1.25: return "✅ KARARLI"
        return "☢ KARARSIZ (Radyoaktif)"
    return "..."

def dunyayi_analiz_et():
    if not parcaciklar: return [], "Atom mühendisine hoş geldiniz.\nLütfen parçacık ekleyin."
    
    # Nükleonları (P ve N) atom çekirdeği olarak grupla
    nukleonlar = [p for p in parcaciklar if p.tip != 'e']
    kumeler, ziyaret = [], set()
    for i, p1 in enumerate(nukleonlar):
        if i in ziyaret: continue
        kume, stack = [], [i]
        ziyaret.add(i)
        while stack:
            idx = stack.pop(); kume.append(nukleonlar[idx])
            for j, p2 in enumerate(nukleonlar):
                if j not in ziyaret and np.linalg.norm(nukleonlar[idx].pos - p2.pos) < 2.0:
                    ziyaret.add(j); stack.append(j)
        kumeler.append(kume)
    
    atomlar = []
    rapor = "--- AI ANALİZ PANELİ ---\n\n"
    for k in kumeler:
        z = sum(1 for p in k if p.tip == 'p')
        n = len(k) - z
        isim = ELEMENTLER.get(z, f"Bilinmeyen-{z}")
        rapor += f"ELEMENT: {isim}\n"
        rapor += f"DURUM: {kararlilik_analizi(z, n)}\n\n"
        atomlar.append({'merkez': np.mean([p.pos for p in k], axis=0), 'z': z})
    return atomlar, rapor

# -------------------------
# Ana Görselleştirme Fonksiyonu
# -------------------------
fig, ax = plt.subplots(figsize=(10, 8))
plt.subplots_adjust(bottom=0.2, right=0.7)
ax.set_facecolor('#050505')
ax.set_xlim(-15, 15); ax.set_ylim(-15, 15)

# Dağılım grafiği (edgecolors='white' atomları belirginleştirir)
scat = ax.scatter([], [], s=[], c=[], edgecolors='white', linewidths=0.5, zorder=3)
rapor_metni = fig.text(0.72, 0.85, "", color='#00FF00', family='monospace', va='top', fontsize=9)

def guncelle(frame):
    atomlar, rapor = dunyayi_analiz_et()
    rapor_metni.set_text(rapor)
    
    if not duraklatildi and parcaciklar:
        kuvvetler = [np.zeros(2) for _ in parcaciklar]
        for i in range(len(parcaciklar)):
            for j in range(i+1, len(parcaciklar)):
                p1, p2 = parcaciklar[i], parcaciklar[j]
                r_vec = p1.pos - p2.pos
                d = np.linalg.norm(r_vec) + 0.1
                unit = r_vec / d
                f = np.zeros(2)
                # Coulomb İtmesi/Çekimi
                if p1.yuk != 0 and p2.yuk != 0:
                    f += (COULOMB_K * p1.yuk * p2.yuk / d**2) * unit
                # Nükleer Kuvvet (P-P, P-N, N-N arası)
                if p1.tip != 'e' and p2.tip != 'e':
                    f += (-GUCLU_CEKIM * np.exp(-d/0.8) + GUCLU_ITIM * np.exp(-d/0.4)) * unit
                # Elektron katmanı engeli
                if (p1.tip == 'e' or p2.tip == 'e') and d < 1.2:
                    f += (12.0 / d**3) * unit
                
                kuvvetler[i] += f
                kuvvetler[j] -= f
        
        # Hareket Güncelleme (Fizik hatasının çözüldüğü yer)
        for i, p in enumerate(parcaciklar):
            ivme = kuvvetler[i] / p.mass
            p.vel = (p.vel + ivme * DT) * SURTUNME
            p.pos += p.vel * DT

    # Görsel veriyi güncelle
    if parcaciklar:
        scat.set_offsets([p.pos for p in parcaciklar])
        scat.set_color([p.renk for p in parcaciklar])
        scat.set_sizes([p.boyut for p in parcaciklar])
    else:
        scat.set_offsets(np.empty((0,2)))
    
    return scat,

# -------------------------
# Buton ve Tıklama Kontrolleri
# -------------------------
def click_event(event):
    if event.inaxes == ax:
        new_p = Parcacik([event.xdata, event.ydata], secili_mod)
        parcaciklar.append(new_p)
        print(f"Eklendi: {secili_mod}")

def mod_degis(m):
    global secili_mod
    secili_mod = m

def dur_devam(e):
    global duraklatildi
    duraklatildi = not duraklatildi
    b_dur.label.set_text('DEVAM ET' if duraklatildi else 'DURAKLAT')

def her_seyi_sil(e):
    parcaciklar.clear()

ax_p = plt.axes([0.05, 0.05, 0.1, 0.06]); b_p = Button(ax_p, 'PROTON', color='#FF3333')
ax_n = plt.axes([0.16, 0.05, 0.1, 0.06]); b_n = Button(ax_n, 'NÖTRON', color='#3333FF')
ax_e = plt.axes([0.27, 0.05, 0.1, 0.06]); b_e = Button(ax_e, 'ELEKTRON', color='#00FFFF')
ax_dur = plt.axes([0.42, 0.05, 0.12, 0.06]); b_dur = Button(ax_dur, 'DURAKLAT', color='gray')
ax_tem = plt.axes([0.58, 0.05, 0.1, 0.06]); b_tem = Button(ax_tem, 'TEMİZLE')

b_p.on_clicked(lambda x: mod_degis('p'))
b_n.on_clicked(lambda x: mod_degis('n'))
b_e.on_clicked(lambda x: mod_degis('e'))
b_dur.on_clicked(dur_devam)
b_tem.on_clicked(her_seyi_sil)

fig.canvas.mpl_connect('button_press_event', click_event)

ani = FuncAnimation(fig, guncelle, interval=20, blit=False)
plt.title("Moleküler AI Simülasyonu (Atomun İçini Doldurduk)", color='white')
plt.show()