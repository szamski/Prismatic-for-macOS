import type { Metadata } from 'next'
import { Unbounded, Instrument_Sans, IBM_Plex_Mono } from 'next/font/google'
import './globals.css'

const display = Unbounded({ subsets: ['latin'], weight: ['400', '600', '800'], variable: '--font-display' })
const body = Instrument_Sans({ subsets: ['latin'], variable: '--font-body' })
const mono = IBM_Plex_Mono({ subsets: ['latin'], weight: ['400', '500'], variable: '--font-mono' })

export const metadata: Metadata = {
  title: 'Prismatic — SteelSeries Arena 7 RGB control for macOS',
  description:
    'A tiny native macOS menu-bar app that controls SteelSeries Arena 7 RGB lighting directly over USB — no SteelSeries GG required.',
  metadataBase: new URL('https://szamski.github.io/Prismatic-for-macOS'),
  openGraph: {
    title: 'Prismatic for macOS',
    description: 'SteelSeries Arena 7 RGB control from the menu bar — no SteelSeries GG required.',
    images: [`${process.env.NEXT_PUBLIC_BASE_PATH ?? ''}/icon.png`],
  },
  icons: { icon: `${process.env.NEXT_PUBLIC_BASE_PATH ?? ''}/icon.png` },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${display.variable} ${body.variable} ${mono.variable}`}>
      <body>{children}</body>
    </html>
  )
}
