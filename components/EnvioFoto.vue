<template>
  <div>
    <label class="envio-foto">
      <input type="file" accept="image/*" capture="environment" @change="selecionar" />
      <template v-if="!previa">
        <div style="font-size:26px">&#128247;</div>
        <div style="font-weight:600;font-size:14px;margin-top:8px">{{ texto }}</div>
        <div class="mini" style="margin-top:4px">Toque para usar a camera ou escolher da galeria</div>
      </template>
      <img v-else :src="previa" class="envio-previa" alt="Comprovante escolhido" />
    </label>
    <div v-if="previa" class="centro" style="margin-top:10px">
      <button class="btn-linha" @click="limpar">Trocar a foto</button>
    </div>
  </div>
</template>

<script setup lang="ts">
withDefaults(defineProps<{ texto?: string }>(), { texto: 'Anexar comprovante da venda' })
const emit = defineEmits<{ (e: 'arquivo', f: File | null): void }>()

const previa = ref<string | null>(null)

function selecionar(ev: Event) {
  const f = (ev.target as HTMLInputElement).files?.[0] ?? null
  if (!f) return
  previa.value = URL.createObjectURL(f)
  emit('arquivo', f)
}
function limpar() { previa.value = null; emit('arquivo', null) }
</script>
