<template>
  <div class="vazio">
    <strong>{{ titulo }}</strong>
    <span>{{ texto }}</span>
  </div>
</template>

<script setup lang="ts">
defineProps<{ titulo: string; texto: string }>()
</script>
