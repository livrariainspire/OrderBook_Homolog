// =====================================================================
//  LIVRARIA INSPIRE — ORDER BOOK
//  Edge Function: "api"  ·  Versao 3.0
//
//  1) CODIGOS DE E-MAIL (rotas publicas)
//     Gera um codigo de 6 digitos, guarda no banco e envia pela API do
//     Brevo. Usado no cadastro e na recuperacao de senha.
//     O Supabase nao envia nenhum e-mail.
//
//  2) ADMINISTRACAO DE CONTAS (rotas protegidas)
//     Criar usuario, trocar senha de qualquer pessoa, excluir conta.
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

// Omie — chaves de integracao do ERP (Edge Functions > Secrets)
const OMIE_APP_KEY    = Deno.env.get("OMIE_APP_KEY") ?? "";
const OMIE_APP_SECRET = Deno.env.get("OMIE_APP_SECRET") ?? "";
const OMIE_BASE       = "https://app.omie.com.br/api/v1/";

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
    + '<p style="margin:0 0 8px;font-size:13px;color:#6f5d55">Seu codigo:</p>'
    + '<div style="background:#fdece6;border-radius:12px;padding:18px;text-align:center;margin-bottom:22px">'
    + '<span style="font-size:34px;font-weight:bold;letter-spacing:10px;color:#d9451d">' + código + '</span></div>'
    + '<p style="margin:0 0 6px;font-size:14px;line-height:1.6;color:#6f5d55">Digite esse codigo na tela do sistema para continuar. Ele vale por ' + VALIDADE_MIN + ' minutos.</p>'
    + '<p style="margin:0;font-size:13px;line-height:1.6;color:#a08e86">Se nao foi voce quem pediu, pode ignorar esta mensagem.</p>'
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
        ? codigo + " e o seu código de confirmação"
        : codigo + " e o seu código para criar uma nova senha",
      htmlContent: corpoEmail(codigo, finalidade),
    }),
  });

  if (!resp.ok) {
    console.error("Brevo respondeu", resp.status, await resp.text());
    throw new Error("Não foi possível enviar o e-mail agora. Tente de novo em alguns minutos.");
  }
}

// ---------------------------------------------------------------------
// Codigos
// ---------------------------------------------------------------------
async function criarEEnviarCodigo(email: string, finalidade: string) {
  const desde = new Date(Date.now() - 3600000).toISOString();
  const { count } = await admin
    .from("email_codes").select("id", { count: "exact", head: true })
    .eq("email", email).eq("purpose", finalidade).gte("created_at", desde);

  if ((count ?? 0) >= MAX_ENVIOS_HORA) {
    throw new Error("Você pediu codigos demais na última hora. Aguarde um pouco e tente de novo.");
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

// ---------------------------------------------------------------------
// Omie — chamada generica
// Todas as chamadas sao POST em JSON para .../<modulo>/<recurso>/
// com o corpo { call, app_key, app_secret, param: [ {...} ] }
// ---------------------------------------------------------------------
async function omieCall(recurso: string, call: string, param: Record<string, unknown>) {
  if (!OMIE_APP_KEY || !OMIE_APP_SECRET) {
    throw new Error("As chaves da Omie ainda nao foram configuradas.");
  }

  const resp = await fetch(OMIE_BASE + recurso.replace(/^\/+|\/+$/g, "") + "/", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      call,
      app_key: OMIE_APP_KEY,
      app_secret: OMIE_APP_SECRET,
      param: [param],
    }),
  });

  const texto = await resp.text();
  let dados: any = null;
  try { dados = JSON.parse(texto); } catch { /* resposta nao era JSON */ }

  if (!resp.ok || dados?.faultstring) {
    const motivo = dados?.faultstring ?? texto.slice(0, 300);
    throw new Error("A Omie recusou a chamada: " + motivo);
  }
  return dados;
}

// Le todas as paginas de uma listagem da Omie
// Cada consulta da Omie usa nomes proprios para a paginacao.
// Mandar os dois juntos faz a Omie recusar a chamada.
async function omieListarTudo(
  recurso: string, call: string, base: Record<string, unknown>,
  campoLista: string,
  campoPagina = "pagina", campoPorPagina = "registros_por_pagina",
  porPagina = 50, maxPaginas = 40,
) {
  const tudo: any[] = [];
  let pagina = 1, totalPaginas = 1;

  while (pagina <= totalPaginas && pagina <= maxPaginas) {
    const r = await omieCall(recurso, call, {
      ...base,
      [campoPagina]: pagina,
      [campoPorPagina]: porPagina,
    });
    totalPaginas = Number(r?.total_de_paginas ?? r?.nTotPaginas ?? 1) || 1;
    const lote = r?.[campoLista] ?? [];
    if (Array.isArray(lote)) tudo.push(...lote);
    pagina++;
  }
  return tudo;
}

// =====================================================================
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  const url = new URL(req.url);
  const rota = url.pathname.replace(/^\/api/, "").replace(/\/+$/, "") || "/";

  if (rota === "/" || rota === "/health") {
    return json({ ok: true, service: "inspire-order-book-api", version: "3.3", brevo: !!BREVO_API_KEY, omie: !!(OMIE_APP_KEY && OMIE_APP_SECRET) });
  }

  let corpo: Record<string, any> = {};
  try { corpo = await req.json(); } catch { corpo = {}; }

  try {
    // ---------- ROTAS PUBLICAS ----------

    if (rota === "/cadastro/codigo") {
      const email = normalizaEmail(corpo.email);
      if (!emailValido(email)) return json({ error: "Informe um e-mail válido." }, 400);
      if (await perfilPorEmail(email)) {
        return json({ error: 'Este e-mail ja tem cadastro. Use "Esqueci minha senha".' }, 400);
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
      if (await perfilPorEmail(email)) return json({ error: "Este e-mail ja tem cadastro." }, 400);

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
      // resposta igual exista ou nao a conta, para nao revelar cadastros
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

    // ---------- ROTAS DA ADMINISTRACAO ----------
    const guarda = await exigirAdmin(req);
    if ("error" in guarda) return json({ error: (guarda as any).error }, 403);
    const { user, perfil } = guarda as any;

    switch (rota) {
      // ---- Omie: teste de conexao. So LE dados, nao grava nada ----
      case "/omie/teste": {
        const r = await omieCall("geral/produtos", "ListarProdutos", {
          pagina: 1,
          registros_por_pagina: 3,
          apenas_importado_api: "N",
          filtrar_apenas_omiepdv: "N",
        });

        const amostra = (r?.produto_servico_cadastro ?? []).map((p: any) => ({
          codigo: p.codigo,
          codigo_produto: p.codigo_produto,
          descricao: p.descricao,
          valor_unitario: p.valor_unitario,
        }));

        return json({
          ok: true,
          total_de_produtos: r?.total_de_registros ?? null,
          paginas: r?.total_de_paginas ?? null,
          amostra,
        });
      }

      // ---- Omie: quadro de estoque. Somente leitura ----
      case "/omie/estoque": {
        // 1) produtos cadastrados na Omie
        const produtos = await omieListarTudo(
          "geral/produtos", "ListarProdutos",
          { apenas_importado_api: "N", filtrar_apenas_omiepdv: "N" },
          "produto_servico_cadastro",
        );

        // 2) posicao de estoque. Se falhar, o quadro ainda aparece sem saldo
        const saldos = new Map<string, number>();
        let avisoEstoque: string | null = null;
        try {
          const hoje = new Date();
          const dData = String(hoje.getDate()).padStart(2, "0") + "/"
            + String(hoje.getMonth() + 1).padStart(2, "0") + "/"
            + hoje.getFullYear();

          const pos = await omieListarTudo(
            "estoque/consulta", "ListarPosEstoque",
            { dDataPosicao: dData, cExibeTodos: "S", codigo_local_estoque: 0 },
            "produtos", "nPagina", "nRegPorPagina",
          );
          for (const p of pos) {
            const id = String(p.nCodProd ?? p.codigo_produto ?? "");
            if (id) saldos.set(id, Number(p.nSaldo ?? 0));
          }
        } catch (e) {
          avisoEstoque = String((e as Error).message ?? e);
        }

        // 3) catalogo do Order Book, para mostrar o que ja esta ligado
        const { data: locais } = await admin
          .from("products")
          .select("id, codigo, title, omie_id, active")
          .eq("active", true);

        const porOmieId = new Map<string, any>();
        const porCodigo = new Map<string, any>();
        for (const l of locais ?? []) {
          if (l.omie_id) porOmieId.set(String(l.omie_id), l);
          if (l.codigo) porCodigo.set(String(l.codigo).toUpperCase(), l);
        }

        const linhas = produtos.map((p: any) => {
          const id = String(p.codigo_produto ?? "");
          const cod = String(p.codigo ?? "").toUpperCase();
          const ligado = porOmieId.get(id) ?? porCodigo.get(cod) ?? null;
          return {
            omie_id: p.codigo_produto,
            codigo: p.codigo,
            descricao: p.descricao,
            valor_unitario: p.valor_unitario,
            saldo: saldos.has(id) ? saldos.get(id) : null,
            ligado_a: ligado ? { id: ligado.id, title: ligado.title, codigo: ligado.codigo } : null,
          };
        });

        // 4) o que existe aqui e nao existe la
        const idsLa = new Set(produtos.map((p: any) => String(p.codigo_produto)));
        const codsLa = new Set(produtos.map((p: any) => String(p.codigo ?? "").toUpperCase()));
        const soAqui = (locais ?? [])
          .filter((l) => !(l.omie_id && idsLa.has(String(l.omie_id)))
                      && !(l.codigo && codsLa.has(String(l.codigo).toUpperCase())))
          .map((l) => ({ id: l.id, codigo: l.codigo, title: l.title }));

        return json({
          ok: true,
          aviso_estoque: avisoEstoque,
          total_omie: produtos.length,
          total_catalogo: (locais ?? []).length,
          linhas,
          so_no_order_book: soAqui,
        });
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
