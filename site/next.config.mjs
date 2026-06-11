// Served from https://szamski.github.io/Prismatic-for-macOS
const basePath = process.env.NODE_ENV === 'production' ? '/Prismatic-for-macOS' : ''

/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'export',
  basePath,
  // next/image does not apply basePath to unoptimized static-export srcs,
  // so components prefix asset URLs with this themselves.
  env: { NEXT_PUBLIC_BASE_PATH: basePath },
  images: { unoptimized: true },
}

export default nextConfig
