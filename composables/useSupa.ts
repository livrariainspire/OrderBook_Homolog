import { createClient, type SupabaseClient } from '@supabase/supabase-js'

let cliente: SupabaseClient | null = null

export function useSupa(): SupabaseClient {
  if (cliente) return cliente
  const cfg = (window as any).__INSPIRE__ || {}
  cliente = createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  })
  return cliente
}

export function configOk(): boolean {
  const cfg = (window as any).__INSPIRE__ || {}
  return !!cfg.SUPABASE_URL && !String(cfg.SUPABASE_URL).includes('COLE_AQUI')
}

/** Chama a Edge Function "api". Envia a sessao quando existe. */
export async function chamarApi(rota: string, corpo: Record<string, any> = {}) {
  const supa = useSupa()
  const { data: { session } } = await supa.auth.getSession()
  const cfg = (window as any).__INSPIRE__ || {}
  const resp = await fetch(`${cfg.SUPABASE_URL}/functions/v1/api${rota}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: cfg.SUPABASE_ANON_KEY,
      Authorization: `Bearer ${session?.access_token ?? cfg.SUPABASE_ANON_KEY}`
    },
    body: JSON.stringify(corpo)
  })
  const dados = await resp.json().catch(() => ({}))
  if (!resp.ok) throw new Error(dados.error || 'Não foi possível concluir a ação.')
  return dados
}
