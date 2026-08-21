export const moeda = (v: number | string | null | undefined) =>
  Number(v ?? 0).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' })

export const dataHora = (v: string | null | undefined) =>
  v ? new Date(v).toLocaleString('pt-BR', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—'

export const dataCurta = (v: string | null | undefined) =>
  v ? new Date(v).toLocaleDateString('pt-BR') : '—'

export const soDigitos = (v: string) => (v || '').replace(/\D/g, '')

export const linkZap = (numero: string) => {
  const n = soDigitos(numero)
  if (!n) return ''
  return 'https://wa.me/' + (n.length <= 11 ? '55' + n : n)
}

export const mascaraZap = (v: string) => {
  const n = soDigitos(v).slice(0, 11)
  if (n.length <= 2) return n
  if (n.length <= 6) return `(${n.slice(0, 2)}) ${n.slice(2)}`
  if (n.length <= 10) return `(${n.slice(0, 2)}) ${n.slice(2, 6)}-${n.slice(6)}`
  return `(${n.slice(0, 2)}) ${n.slice(2, 7)}-${n.slice(7)}`
}

export const rotuloSituacao = (s: string) => ({
  fila: 'Na fila',
  em_atendimento: 'Em atendimento',
  em_espera: 'Em espera',
  enviado: 'Aguardando recebimento',
  finalizado: 'Finalizado',
  cancelado: 'Cancelado',
  pendente: 'Aguardando aprovação',
  aprovado: 'Ativo',
  rejeitado: 'Recusado',
  inativo: 'Inativo'
}[s] ?? s)

export const classeSelo = (s: string) => ({
  fila: 'selo-fila',
  em_atendimento: 'selo-atendimento',
  em_espera: 'selo-espera',
  enviado: 'selo-laranja',
  finalizado: 'selo-enviado',
  cancelado: 'selo-cancelado',
  pendente: 'selo-fila',
  aprovado: 'selo-enviado',
  rejeitado: 'selo-cancelado',
  inativo: 'selo-neutro'
}[s] ?? 'selo-neutro')
