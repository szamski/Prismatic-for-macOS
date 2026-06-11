import Image from 'next/image'
import CopyButton from '@/components/CopyButton'

const GH = 'https://github.com/szamski/Prismatic-for-macOS'
const BREW = 'brew install szamski/tap/prismatic'
const BP = process.env.NEXT_PUBLIC_BASE_PATH ?? ''

const FEATURES = [
  {
    k: '01',
    title: 'Left / right colors',
    text: 'Each speaker drives two of the Arena 7’s four RGB zones — set them together or independently.',
  },
  {
    k: '02',
    title: 'Wallpaper palette',
    text: 'One click extracts the dominant colors of your desktop wallpaper and puts them on the speakers.',
  },
  {
    k: '03',
    title: 'Direct USB HID',
    text: 'Talks straight to the hardware over a reverse-engineered USB protocol. No SteelSeries GG, no background services.',
  },
  {
    k: '04',
    title: 'Inline color picker',
    text: 'A custom picker that lives right inside the menu — no clunky floating system panels.',
  },
  {
    k: '05',
    title: 'Brightness & power',
    text: 'Hardware brightness control and instant on/off, one click away in the menu bar.',
  },
  {
    k: '06',
    title: '~1 MB, native',
    text: 'Pure SwiftUI. Launch at login, built-in update check, signed & notarized. That’s the whole app.',
  },
]

const PACKET: { byte: string; cls: string; note: string }[] = [
  { byte: '0x06', cls: 'b-id', note: 'report ID' },
  { byte: '0xA1', cls: 'b-cmd', note: 'set static colors' },
  { byte: 'R', cls: 'b-r', note: 'zone red' },
  { byte: 'G', cls: 'b-g', note: 'zone green' },
  { byte: 'B', cls: 'b-b', note: 'zone blue' },
  { byte: '0x01', cls: 'b-dim', note: '' },
  { byte: '0x1E', cls: 'b-dim', note: '' },
  { byte: '0…10', cls: 'b-br', note: 'brightness' },
  { byte: '×4', cls: 'b-dim', note: 'zones' },
  { byte: '0x0F', cls: 'b-id', note: 'terminator' },
]

export default function Home() {
  return (
    <main>
      <div className="glow" aria-hidden />
      <div className="grain" aria-hidden />

      {/* ───────────────── hero ───────────────── */}
      <section className="hero">
        <p className="eyebrow">macOS 14+ · menu bar · usb hid</p>

        <Image src={`${BP}/icon.png`} alt="Prismatic app icon" width={132} height={132} className="app-icon" priority />

        <h1>
          PRIS<span className="rgb">MAT</span>IC
        </h1>

        <p className="tagline">
          <strong>SteelSeries Arena 7</strong> RGB control from the macOS menu bar —{' '}
          <em>no SteelSeries GG required.</em>
        </p>

        <div className="install">
          <code className="brew">
            <span className="prompt">$</span> {BREW}
            <CopyButton text={BREW} />
          </code>
          <div className="cta-row">
            <a className="btn btn-primary" href={`${GH}/releases/latest`}>
              Download .dmg
            </a>
            <a className="btn btn-ghost" href={GH}>
              View on GitHub
            </a>
          </div>
        </div>
      </section>

      {/* ───────────────── demo ───────────────── */}
      <section className="demo">
        <div className="mac-window">
          <div className="mac-titlebar" aria-hidden>
            <i className="dot dot-r" />
            <i className="dot dot-y" />
            <i className="dot dot-g" />
          </div>
          <Image src={`${BP}/demo.gif`} alt="Prismatic menu in action" width={320} height={560} unoptimized className="demo-gif" />
        </div>
        <p className="demo-caption">Pick colors, pull a palette from your wallpaper, dim, toggle — done.</p>
      </section>

      {/* ───────────────── why ───────────────── */}
      <section className="why">
        <h2>
          <span className="sec-num">/01</span> Why
        </h2>
        <p>
          SteelSeries GG is a multi-hundred-megabyte Electron + background-service suite — just to change a color.
          Prismatic does the one thing, lighting, <strong>natively, instantly, and out of your way</strong>. The USB
          protocol was reverse-engineered so the app talks to the hardware on its own.
        </p>
      </section>

      {/* ───────────────── features ───────────────── */}
      <section className="features">
        <h2>
          <span className="sec-num">/02</span> Features
        </h2>
        <div className="grid">
          {FEATURES.map((f) => (
            <article key={f.k} className="card">
              <span className="card-num">{f.k}</span>
              <h3>{f.title}</h3>
              <p>{f.text}</p>
            </article>
          ))}
        </div>
      </section>

      {/* ───────────────── protocol ───────────────── */}
      <section className="protocol">
        <h2>
          <span className="sec-num">/03</span> How it works
        </h2>
        <p>
          The Arena 7 exposes a vendor HID interface (<code>VID:PID 0x1038:0x1A00</code>). Lighting is one Output
          report, recovered from a USBPcap capture of SteelSeries GG:
        </p>
        <div className="packet" role="img" aria-label="USB lighting packet byte layout">
          {PACKET.map((b, i) => (
            <span key={i} className={`pbyte ${b.cls}`}>
              <span className="pval">{b.byte}</span>
              {b.note && <span className="pnote">{b.note}</span>}
            </span>
          ))}
        </div>
        <p className="protocol-foot">
          Got another SteelSeries device GG can light up? It can probably be supported too —{' '}
          <a href={`${GH}/issues/new?template=new-device.yml`}>open a device request</a>.
        </p>
      </section>

      {/* ───────────────── footer ───────────────── */}
      <footer>
        <p>
          <a href={`${GH}/blob/main/LICENSE`}>MIT</a> © 2026 Maciej Szamowski · <a href={GH}>GitHub</a>
        </p>
        <p className="fine">
          Prismatic is unofficial and not affiliated with or endorsed by SteelSeries. The USB protocol was
          reverse-engineered for interoperability. SteelSeries, Arena, and PrismSync are trademarks of their
          respective owners.
        </p>
      </footer>
    </main>
  )
}
