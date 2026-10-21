// web/next.config.js
import { fileURLToPath } from 'url';
import { dirname } from 'path';

/** @type {import('next').NextConfig} */
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const nextConfig = {
  // تفعيل وضع React الصارم
  reactStrictMode: true,

  // استخدام SWC للتصغير
  swcMinify: true,

  // إعدادات Turbopack مع تحديد الجذر
  experimental: {
    turbopack: {
      root: __dirname
    }
  },

  // إعدادات الصور
  images: {
    domains: []
  },

  // إعدادات تعدد اللغات
  i18n: {
    locales: ['ar', 'en'],
    defaultLocale: 'ar'
  }
};

export default nextConfig;
