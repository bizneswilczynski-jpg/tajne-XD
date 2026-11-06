# Wdrożenie (Cloudflare Workers, darmowy plan)

1. `npm install`
2. `npx wrangler login`  (otwiera przeglądarkę, kliknij Allow)
3. `npx wrangler kv namespace create STATE` i wpisz zwrócone `id` do sekcji `[[kv_namespaces]]` w wrangler.toml
4. `npx wrangler deploy`
5. `npx wrangler secret put KEY` (tajny fragment adresu apki)
6. Adres apki: `https://zastrzyki.<subdomena>.workers.dev/<KEY>/`
