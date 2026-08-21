// =====================================================================
//  LIVRARIA INSPIRE — ORDER BOOK
//  Edge Function: "api"  ·  Versao 3.0
//
//  1) CÓDIGOS DE E-MAIL (rotas públicas)
//     Gera um código de 6 dígitos, guarda no banco e envia pela API do
//     Brevo. Usado no cadastro e na recuperação de senha.
//     O Supabase não envia nenhum e-mail.
//
//  2) ADMINISTRAÇÃO DE CONTAS (rotas protegidas)
//     Criar usuário, trocar senha de qualquer pessoa, excluir conta.
//
//  Segredos necessarios em Edge Functions > Secrets:
//     BREVO_API_KEY      chave v3 da API do Brevo
//     BREVO_SENDER       e-mail remetente verificado no Brevo
//     BREVO_SENDER_NAME  nome do remetente (opcional)
// =====================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const SUPABASE_URL  = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY      = Deno.env.get("SUPABASE_ANON_KEY")!;
const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY") ?? "";
const BREVO_SENDER  = Deno.env.get("BREVO_SENDER") ?? "livraria.app@livrariainspire.com.br";
const BREVO_NAME    = Deno.env.get("BREVO_SENDER_NAME") ?? "Livraria Inspire";

const VALIDADE_MIN    = 15;
const MAX_TENTATIVAS  = 5;
const MAX_ENVIOS_HORA = 6;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

const admin = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// ---------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------
const normalizaEmail = (e: unknown) => String(e ?? "").trim().toLowerCase();
const emailValido = (e: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e);
const soDigitos = (v: unknown) => String(v ?? "").replace(/\D/g, "");

function gerarCodigo(): string {
  const n = new Uint32Array(1);
  crypto.getRandomValues(n);
  return String(n[0] % 1000000).padStart(6, "0");
}

async function hash(email: string, codigo: string): Promise<string> {
  const dados = new TextEncoder().encode(email + ":" + codigo);
  const buf = await crypto.subtle.digest("SHA-256", dados);
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function perfilPorEmail(email: string) {
  const { data } = await admin
    .from("profiles").select("id, full_name, email, status")
    .eq("email", email).maybeSingle();
  return data;
}

// ---------------------------------------------------------------------
// Envio pelo Brevo
// ---------------------------------------------------------------------
function corpoEmail(codigo: string, finalidade: string) {
  const titulo = finalidade === "cadastro" ? "Confirme seu e-mail" : "Recuperar sua senha";
  const frase = finalidade === "cadastro"
    ? "Você está criando uma conta no Order Book, o sistema de pedidos da Livraria Inspire."
    : "Você pediu para criar uma nova senha no Order Book, o sistema de pedidos da Livraria Inspire.";

  return '<!doctype html><html lang="pt-BR"><body style="margin:0;padding:0;background:#fdf7f4;font-family:Helvetica,Arial,sans-serif">'
    + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#fdf7f4;padding:32px 16px"><tr><td align="center">'
    + '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:16px;padding:32px"><tr><td>'
    + '<p style="margin:0 0 4px;font-size:12px;letter-spacing:2px;text-transform:uppercase;color:#a08e86">Livraria Inspire</p>'
    + '<h1 style="margin:0 0 18px;font-size:22px;color:#2c2320">' + titulo + '</h1>'
    + '<p style="margin:0 0 22px;font-size:15px;line-height:1.6;color:#6f5d55">' + frase + '</p>'
    + '<p style="margin:0 0 8px;font-size:13px;color:#6f5d55">Seu código:</p>'
    + '<div style="background:#fdece6;border-radius:12px;padding:18px;text-align:center;margin-bottom:22px">'
    + '<span style="font-size:34px;font-weight:bold;letter-spacing:10px;color:#d9451d">' + código + '</span></div>'
    + '<p style="margin:0 0 6px;font-size:14px;line-height:1.6;color:#6f5d55">Digite esse código na tela do sistema para continuar. Ele vale por ' + VALIDADE_MIN + ' minutos.</p>'
    + '<p style="margin:0;font-size:13px;line-height:1.6;color:#a08e86">Se não foi você quem pediu, pode ignorar esta mensagem.</p>'
    + '</td></tr></table>'
    + '<p style="margin:20px 0 0;font-size:12px;color:#a08e86">Order Book &middot; Livraria Inspire</p>'
    + '</td></tr></table></body></html>';
}

async function enviarBrevo(email: string, codigo: string, finalidade: string) {
  if (!BREVO_API_KEY) {
    throw new Error("O envio de e-mail ainda não foi configurado. Fale com a administração.");
  }

  const resp = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": BREVO_API_KEY,
      "Content-Type": "application/json",
      accept: "application/json",
    },
    body: JSON.stringify({
      sender: { name: BREVO_NAME, email: BREVO_SENDER },
      to: [{ email }],
      subject: finalidade === "cadastro"
        ? codigo + " é o seu código de confirmação"
        : codigo + " é o seu código para criar uma nova senha",
      htmlContent: corpoEmail(codigo, finalidade),
    }),
  });

  if (!resp.ok) {
    console.error("Brevo respondeu", resp.status, await resp.text());
    throw new Error("Não foi possível enviar o e-mail agora. Tente de novo em alguns minutos.");
  }
}

// ---------------------------------------------------------------------
// Códigos
// ---------------------------------------------------------------------
async function criarEEnviarCodigo(email: string, finalidade: string) {
  const desde = new Date(Date.now() - 3600000).toISOString();
  const { count } = await admin
    .from("email_codes").select("id", { count: "exact", head: true })
    .eq("email", email).eq("purpose", finalidade).gte("created_at", desde);

  if ((count ?? 0) >= MAX_ENVIOS_HORA) {
    throw new Error("Você pediu códigos demais na última hora. Aguarde um pouco e tente de novo.");
  }

  await admin.from("email_codes")
    .update({ used_at: new Date().toISOString() })
    .eq("email", email).eq("purpose", finalidade).is("used_at", null);

  const codigo = gerarCodigo();
  const { error } = await admin.from("email_codes").insert({
    email,
    purpose: finalidade,
    code_hash: await hash(email, codigo),
    expires_at: new Date(Date.now() + VALIDADE_MIN * 60000).toISOString(),
  });
  if (error) throw new Error("Não foi possível gerar o código. Tente de novo.");

  await enviarBrevo(email, codigo, finalidade);
}

async function conferirCodigo(email: string, codigo: unknown, finalidade: string): Promise<string | null> {
  const limpo = soDigitos(codigo);
  if (limpo.length !== 6) return "Digite os 6 números do código.";

  const { data: reg } = await admin
    .from("email_codes").select("*")
    .eq("email", email).eq("purpose", finalidade).is("used_at", null)
    .order("created_at", { ascending: false }).limit(1).maybeSingle();

  if (!reg) return "Nenhum código em aberto para este e-mail. Peça um novo.";
  if (new Date(reg.expires_at) < new Date()) return "Este código expirou. Peça um novo.";

  if (reg.attempts >= MAX_TENTATIVAS) {
    await admin.from("email_codes").update({ used_at: new Date().toISOString() }).eq("id", reg.id);
    return "Código bloqueado por excesso de tentativas. Peça um novo.";
  }

  if (reg.code_hash !== await hash(email, limpo)) {
    await admin.from("email_codes").update({ attempts: reg.attempts + 1 }).eq("id", reg.id);
    const restam = MAX_TENTATIVAS - (reg.attempts + 1);
    return restam > 0
      ? "Código incorreto. Você ainda tem " + restam + " tentativa(s)."
      : "Código incorreto. Peça um novo código.";
  }

  await admin.from("email_codes").update({ used_at: new Date().toISOString() }).eq("id", reg.id);
  return null;
}


// ---------------------------------------------------------------------
// OMIE — processa a fila de pedidos de venda
//
// Em modo simulação nada sai daqui: o sistema grava o que teria sido
// enviado, para você conferir o formato. Ao preencher as chaves da
// Omie e desligar a simulação, o mesmo código passa a enviar de verdade.
// ---------------------------------------------------------------------
const OMIE_URL = "https://app.omie.com.br/api/v1/produtos/pedido/";

async function lerConfig(): Promise<Record<string, string | null>> {
  const { data } = await admin.from("settings").select("key, value");
  const cfg: Record<string, string | null> = {};
  (data ?? []).forEach((r: any) => { cfg[r.key] = r.value; });
  return cfg;
}

/** Monta o corpo do Pedido de Venda no formato que a Omie espera. */
function montarPedidoOmie(p: any, cfg: Record<string, string | null>) {
  const det = (p.itens ?? []).map((i: any, n: number) => ({
    ide: { codigo_item_integracao: String(n + 1) },
    produto: {
      codigo_produto: i.produto?.codigo_produto_omie ?? undefined,
      descricao: i.produto?.descricao,
      quantidade: Number(i.produto?.quantidade ?? 0),
      valor_unitario: Number(i.produto?.valor_unitario ?? 0),
    },
  }));

  return {
    cabecalho: {
      codigo_pedido_integracao: p.codigo_pedido_integracao,
      codigo_cliente: p.codigo_cliente_omie ? Number(p.codigo_cliente_omie) : undefined,
      data_previsao: p.data_previsao,
      etapa: p.etapa ?? "10",
      codigo_parcela: p.parcelas && p.parcelas > 1 ? "999" : "000",
      quantidade_itens: det.length,
    },
    det,
    informacoes_adicionais: {
      codigo_categoria: p.codigo_categoria ?? undefined,
      codigo_conta_corrente: p.codigo_conta_corrente ? Number(p.codigo_conta_corrente) : undefined,
      consumidor_final: "S",
      enviar_email: "N",
      utilizar_emails: undefined,
    },
    frete: { modalidade: "9" },
    observacoes: {
      obs_venda: `${p.filial ?? ""} · ${p.forma_pagamento ?? ""}`.trim(),
    },
  };
}

async function processarFilaOmie(limite = 20) {
  const cfg = await lerConfig();
  const simulado = (cfg["modo_simulacao"] ?? "true") === "true";
  const appKey = cfg["omie_app_key"] ?? "";
  const appSecret = cfg["omie_app_secret"] ?? "";

  const { data: fila } = await admin
    .from("omie_queue").select("*")
    .eq("status", "pendente")
    .order("created_at")
    .limit(limite);

  const resultado: any[] = [];

  for (const item of fila ?? []) {
    const corpo = montarPedidoOmie(item.payload, cfg);

    // ---- modo simulação: registra o que seria enviado ----
    if (simulado || !appKey || !appSecret) {
      await admin.rpc("fn_omie_marcar", {
        p_id: item.id,
        p_status: "simulado",
        p_resposta: {
          simulado: true,
          motivo: simulado ? "Modo simulação ligado" : "Chaves da Omie não preenchidas",
          endereco: OMIE_URL,
          enviaria: { call: "IncluirPedido", app_key: "***", app_secret: "***", param: [corpo] },
        },
        p_erro: null,
      });
      resultado.push({ id: item.id, status: "simulado" });
      continue;
    }

    // ---- envio de verdade ----
    try {
      const resp = await fetch(OMIE_URL, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          call: "IncluirPedido",
          app_key: appKey,
          app_secret: appSecret,
          param: [corpo],
        }),
      });
      const dados = await resp.json().catch(() => ({}));

      if (!resp.ok || dados.faultstring) {
        await admin.rpc("fn_omie_marcar", {
          p_id: item.id, p_status: "erro", p_resposta: dados,
          p_erro: dados.faultstring ?? ("A Omie respondeu " + resp.status),
        });
        resultado.push({ id: item.id, status: "erro", erro: dados.faultstring });
      } else {
        await admin.rpc("fn_omie_marcar", {
          p_id: item.id, p_status: "enviado", p_resposta: dados, p_erro: null,
        });
        resultado.push({ id: item.id, status: "enviado" });
      }
    } catch (e) {
      await admin.rpc("fn_omie_marcar", {
        p_id: item.id, p_status: "erro", p_resposta: null,
        p_erro: String((e as Error).message ?? e),
      });
      resultado.push({ id: item.id, status: "erro" });
    }
  }

  return { processados: resultado.length, simulado, itens: resultado };
}

// ---------------------------------------------------------------------
async function exigirAdmin(req: Request) {
  const token = (req.headers.get("Authorization") ?? "").replace("Bearer ", "").trim();
  if (!token || token === ANON_KEY) return { error: "Faca login para continuar." };

  const comoUsuario = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: "Bearer " + token } },
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data, error } = await comoUsuario.auth.getUser();
  if (error || !data?.user) return { error: "Sessao expirada. Entre novamente." };

  const { data: perfil } = await admin
    .from("profiles").select("id, full_name, role, status").eq("id", data.user.id).single();

  if (!perfil || perfil.role !== "admin" || perfil.status !== "aprovado") {
    return { error: "Esta ação é exclusiva da administração." };
  }
  return { user: data.user, perfil };
}

async function registrar(ator: string | null, nome: string | null, acao: string, alvo: string | null, detalhes: unknown) {
  await admin.from("activity_log").insert({
    actor_id: ator, actor_name: nome, action: acao,
    entity: "profiles", entity_id: alvo, details: detalhes,
  });
}

// =====================================================================
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = new URL(req.url);
  const rota = url.pathname.replace(/^\/api/, "").replace(/\/+$/, "") || "/";

  if (rota === "/" || rota === "/health") {
    return json({ ok: true, service: "inspire-order-book-api", version: "3.0", brevo: !!BREVO_API_KEY });
  }

  let corpo: Record<string, any> = {};
  try { corpo = await req.json(); } catch { corpo = {}; }

  try {
    // ---------- ROTAS PUBLICAS ----------

    if (rota === "/cadastro/codigo") {
      const email = normalizaEmail(corpo.email);
      if (!emailValido(email)) return json({ error: "Informe um e-mail válido." }, 400);
      if (await perfilPorEmail(email)) {
        return json({ error: 'Este e-mail já tem cadastro. Use "Esqueci minha senha".' }, 400);
      }
      await criarEEnviarCodigo(email, "cadastro");
      return json({ ok: true });
    }

    if (rota === "/cadastro/confirmar") {
      const email = normalizaEmail(corpo.email);
      const { code, full_name, whatsapp, password } = corpo;

      if (!emailValido(email)) return json({ error: "Informe um e-mail válido." }, 400);
      if (!full_name || String(full_name).trim().length < 3) return json({ error: "Informe seu nome completo." }, 400);
      if (!password || String(password).length < 8) return json({ error: "A senha precisa ter ao menos 8 caracteres." }, 400);
      if (await perfilPorEmail(email)) return json({ error: "Este e-mail já tem cadastro." }, 400);

      const problema = await conferirCodigo(email, code, "cadastro");
      if (problema) return json({ error: problema }, 400);

      const { error } = await admin.auth.admin.createUser({
        email,
        password: String(password),
        email_confirm: true,
        user_metadata: { full_name: String(full_name).trim(), whatsapp: soDigitos(whatsapp) },
      });
      if (error) return json({ error: "Não foi possível concluir o cadastro: " + error.message }, 400);
      return json({ ok: true });
    }

    if (rota === "/senha/codigo") {
      const email = normalizaEmail(corpo.email);
      if (!emailValido(email)) return json({ error: "Informe um e-mail válido." }, 400);
      // resposta igual exista ou não a conta, para não revelar cadastros
      if (await perfilPorEmail(email)) await criarEEnviarCodigo(email, "recuperacao");
      return json({ ok: true });
    }

    if (rota === "/senha/redefinir") {
      const email = normalizaEmail(corpo.email);
      const { code, password } = corpo;
      if (!password || String(password).length < 8) {
        return json({ error: "A senha precisa ter ao menos 8 caracteres." }, 400);
      }
      const problema = await conferirCodigo(email, code, "recuperacao");
      if (problema) return json({ error: problema }, 400);

      const perfil = await perfilPorEmail(email);
      if (!perfil) return json({ error: "Conta não encontrada." }, 400);

      const { error } = await admin.auth.admin.updateUserById(perfil.id, {
        password: String(password), email_confirm: true,
      });
      if (error) return json({ error: "Não foi possível trocar a senha: " + error.message }, 400);

      await registrar(null, perfil.full_name || email, "senha_recuperada", perfil.id, {});
      return json({ ok: true });
    }

    // ---------- ROTAS DA ADMINISTRAÇÃO ----------
    const guarda = await exigirAdmin(req);
    if ("error" in guarda) return json({ error: (guarda as any).error }, 403);
    const { user, perfil } = guarda as any;

    switch (rota) {
      // ---------------------------------------------------------------
      // Processa a fila da Omie (simulado ou real)
      // ---------------------------------------------------------------
      case "/omie/processar": {
        const r = await processarFilaOmie(Number(corpo.limite ?? 20));
        return json({ ok: true, ...r });
      }

      // Testa as chaves da Omie sem gravar nada
      case "/omie/testar": {
        const cfg = await lerConfig();
        const appKey = cfg["omie_app_key"] ?? "";
        const appSecret = cfg["omie_app_secret"] ?? "";
        if (!appKey || !appSecret) {
          return json({ ok: false, mensagem: "As chaves da Omie ainda não foram preenchidas." });
        }
        const resp = await fetch("https://app.omie.com.br/api/v1/geral/clientes/", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            call: "ListarClientes", app_key: appKey, app_secret: appSecret,
            param: [{ pagina: 1, registros_por_pagina: 1, apenas_importado_api: "N" }],
          }),
        });
        const dados = await resp.json().catch(() => ({}));
        if (dados.faultstring) return json({ ok: false, mensagem: dados.faultstring });
        return json({ ok: true, mensagem: "Conexão com a Omie funcionando.",
                      clientes: dados.total_de_registros ?? null });
      }

      case "/create-user": {
        const { password, full_name, whatsapp, role, unit_id } = corpo;
        const alvo = normalizaEmail(corpo.email);
        if (!emailValido(alvo) || !password) return json({ error: "Informe e-mail e senha." }, 400);
        if (String(password).length < 8) return json({ error: "A senha precisa ter ao menos 8 caracteres." }, 400);

        const { data, error } = await admin.auth.admin.createUser({
          email: alvo, password: String(password), email_confirm: true,
          user_metadata: { full_name: full_name ?? "", whatsapp: soDigitos(whatsapp) },
        });
        if (error) return json({ error: error.message }, 400);

        const novoId = data.user!.id;
        await admin.from("profiles").upsert({
          id: novoId,
          full_name: full_name ?? "",
          email: alvo,
          whatsapp: soDigitos(whatsapp),
          role: role || null,
          unit_id: role === "igreja" || role === "ponto" ? unit_id ?? null : null,
          status: role ? "aprovado" : "pendente",
          approved_at: role ? new Date().toISOString() : null,
          approved_by: role ? user.id : null,
        });

        await registrar(user.id, perfil.full_name, "usuario_criado", novoId, { email: alvo, role });
        return json({ ok: true, user_id: novoId });
      }

      case "/update-user": {
        const { user_id } = corpo;
        const novoEmail = normalizaEmail(corpo.email);
        if (!user_id) return json({ error: "Informe o usuário." }, 400);
        if (!emailValido(novoEmail)) return json({ error: "Informe um e-mail válido." }, 400);

        const jaUsado = await perfilPorEmail(novoEmail);
        if (jaUsado && jaUsado.id !== user_id) {
          return json({ error: "Este e-mail já pertence a outro cadastro." }, 400);
        }

        const { error } = await admin.auth.admin.updateUserById(user_id, {
          email: novoEmail, email_confirm: true,
        });
        if (error) return json({ error: error.message }, 400);

        await admin.from("profiles").update({ email: novoEmail }).eq("id", user_id);
        await registrar(user.id, perfil.full_name, "email_alterado", user_id, { email: novoEmail });
        return json({ ok: true });
      }

      case "/set-password": {
        const { user_id, password } = corpo;
        if (!user_id || !password) return json({ error: "Informe o usuário e a nova senha." }, 400);
        if (String(password).length < 8) return json({ error: "A senha precisa ter ao menos 8 caracteres." }, 400);
        const { error } = await admin.auth.admin.updateUserById(user_id, { password: String(password) });
        if (error) return json({ error: error.message }, 400);
        await registrar(user.id, perfil.full_name, "senha_redefinida", user_id, {});
        return json({ ok: true });
      }

      case "/delete-user": {
        const { user_id } = corpo;
        if (!user_id) return json({ error: "Informe o usuário." }, 400);
        if (user_id === user.id) return json({ error: "Você não pode excluir a própria conta." }, 400);
        const { error } = await admin.auth.admin.deleteUser(user_id);
        if (error) return json({ error: error.message }, 400);
        await registrar(user.id, perfil.full_name, "usuario_excluido", user_id, {});
        return json({ ok: true });
      }

      default:
        return json({ error: "Rota não encontrada." }, 404);
    }
  } catch (e) {
    return json({ error: String((e as Error).message ?? e) }, 400);
  }
});
