import { I18n } from 'i18n-js';
import { getLocales } from 'expo-localization';

const i18n = new I18n({
  en: {
    welcome: 'Hello',
    select: 'Select',
    edit: 'Edit',
    export: 'Export',
    missing: 'Missing',
    home: 'Home',
    settings: 'Settings',
    preview: 'Preview',
  },
  es: {
    welcome: 'Hola',
    select: 'Seleccionar',
    edit: 'Editar',
    export: 'Exportar',
    missing: 'Faltante',
    home: 'Inicio',
    settings: 'Configuración',
    preview: 'Vista previa',
  },
  fr: {
    welcome: 'Bonjour',
    select: 'Sélectionner',
    edit: 'Éditer',
    export: 'Exporter',
    missing: 'Manquant',
    home: 'Accueil',
    settings: 'Paramètres',
    preview: 'Aperçu',
  },
  de: {
    welcome: 'Hallo',
    select: 'Auswählen',
    edit: 'Bearbeiten',
    export: 'Exportieren',
    missing: 'Fehlt',
    home: 'Startseite',
    settings: 'Einstellungen',
    preview: 'Vorschau',
  },
  pt: {
    welcome: 'Olá',
    select: 'Selecionar',
    edit: 'Editar',
    export: 'Exportar',
    missing: 'Faltando',
    home: 'Início',
    settings: 'Configurações',
    preview: 'Pré-visualização',
  },
  zh: {
    welcome: '你好',
    select: '选择',
    edit: '编辑',
    export: '导出',
    missing: '缺失',
    home: '首页',
    settings: '设置',
    preview: '预览',
  },
  ja: {
    welcome: 'こんにちは',
    select: '選択',
    edit: '編集',
    export: 'エクスポート',
    missing: '不足',
    home: 'ホーム',
    settings: '設定',
    preview: 'プレビュー',
  },
});

i18n.locale = getLocales()[0].languageCode;
i18n.enableFallback = true;

export default i18n;
