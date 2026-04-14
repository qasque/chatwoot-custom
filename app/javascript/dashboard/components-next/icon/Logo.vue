<script setup>
import { useAttrs } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const attrs = useAttrs();
const globalConfig = useMapGetter('globalConfig/get');
const defaultLogoThumbnail = '/brand-assets/kosmos-orbit-mark.png';
</script>

<template>
  <img
    v-if="globalConfig.logoThumbnail"
    v-bind="attrs"
    :src="globalConfig.logoThumbnail"
    alt=""
  />
  <img v-else v-bind="attrs" :src="defaultLogoThumbnail" alt="Космос Чат" />
</template>
