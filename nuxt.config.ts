const base = process.env.NUXT_APP_BASE_URL || '/'

export default defineNuxtConfig({
  ssr: false,
  compatibilityDate: '2024-09-01',
  devtools: { enabled: false },
  css: ['~/assets/css/main.css'],
  nitro: { preset: 'github-pages' },
  app: {
    baseURL: base,
    buildAssetsDir: 'assets',
    head: {
      title: 'Order Book · Livraria Inspire',
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'theme-color', content: '#F05A33' },
        { name: 'description', content: 'Gestão de pedidos, estoque e vendas da Livraria Inspire.' }
      ],
      link: [
        { rel: 'icon', type: 'image/png', href: base + 'logo-inspire.png' },
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600;700&display=swap' }
      ],
      script: [{ src: base + 'config.js' }]
    }
  }
})
