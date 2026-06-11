'use client'

import { useState } from 'react'

export default function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false)

  async function copy() {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
      setTimeout(() => setCopied(false), 1600)
    } catch {
      /* clipboard unavailable — nothing to do */
    }
  }

  return (
    <button className="copy-btn" onClick={copy} aria-label="Copy to clipboard">
      {copied ? 'copied' : 'copy'}
    </button>
  )
}
