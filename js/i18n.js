/**
 * Internationalization (i18n) Module for Browser Launcher Pro
 * Supports multiple languages popular in USA, Canada, Europe, Middle East, and China
 */

// Available languages with their display names and regions
const SUPPORTED_LANGUAGES = {
  'en': { name: 'English', nativeName: 'English', region: 'Global', flag: 'US' },
  'fr': { name: 'French', nativeName: 'Francais', region: 'Canada/Europe', flag: 'FR' },
  'es': { name: 'Spanish', nativeName: 'Espanol', region: 'USA/Europe', flag: 'ES' },
  'de': { name: 'German', nativeName: 'Deutsch', region: 'Europe', flag: 'DE' },
  'it': { name: 'Italian', nativeName: 'Italiano', region: 'Europe', flag: 'IT' },
  'pt': { name: 'Portuguese', nativeName: 'Portugues', region: 'Europe', flag: 'PT' },
  'nl': { name: 'Dutch', nativeName: 'Nederlands', region: 'Europe', flag: 'NL' },
  'pl': { name: 'Polish', nativeName: 'Polski', region: 'Europe', flag: 'PL' },
  'ru': { name: 'Russian', nativeName: 'Russian', region: 'Europe', flag: 'RU' },
  'ar': { name: 'Arabic', nativeName: 'Arabic', region: 'Middle East', flag: 'SA' },
  'he': { name: 'Hebrew', nativeName: 'Hebrew', region: 'Middle East', flag: 'IL' },
  'fa': { name: 'Persian', nativeName: 'Persian', region: 'Middle East', flag: 'IR' },
  'tr': { name: 'Turkish', nativeName: 'Turkce', region: 'Middle East', flag: 'TR' },
  'zh': { name: 'Chinese (Simplified)', nativeName: 'Chinese (Simplified)', region: 'China', flag: 'CN' },
  'zh-TW': { name: 'Chinese (Traditional)', nativeName: 'Chinese (Traditional)', region: 'Taiwan', flag: 'TW' },
  'ja': { name: 'Japanese', nativeName: 'Japanese', region: 'Japan', flag: 'JP' },
  'ko': { name: 'Korean', nativeName: 'Korean', region: 'Korea', flag: 'KR' }
};

// Translation dictionary - organized by language code
const TRANSLATIONS = {
  'en': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'Launch and manage multiple browsers across Windows and WSL with version tracking',
    
    // Navigation tabs
    'nav.windows': 'Windows Local',
    'nav.wsl': 'WSL Ubuntu Linux',
    'nav.settings': 'Settings',
    'nav.versionLog': 'Version Update Log',
    'nav.wslManager': 'WSL Manager',
    'nav.searchSettings': 'Search Settings',
    'nav.helpSupport': 'Help/Support',
    
    // Browser sections
    'browsers.edge.title': 'MICROSOFT EDGE (WINDOWS LOCAL)',
    'browsers.chrome.title': 'GOOGLE CHROME (WINDOWS LOCAL)',
    'browsers.stable': 'Stable',
    'browsers.beta': 'Beta',
    'browsers.dev': 'Dev',
    'browsers.notFound': 'Not Found',
    'browsers.watchVersions': 'Watch for version changes',
    
    // WSL sections
    'wsl.edge.title': 'Microsoft Edge',
    'wsl.chrome.title': 'Google Chrome',
    'wsl.other.title': 'Other Browsers',
    'wsl.tools.title': 'WSL Ubuntu Tools',
    'wsl.firefox': 'Firefox',
    'wsl.opera': 'Opera',
    'wsl.brave': 'Brave',
    'wsl.konsole': 'Launch Konsole',
    'wsl.powershell': 'Launch PowerShell',
    'wsl.sandbox': 'Launch Win Sandbox',
    
    // Settings
    'settings.title': 'Settings',
    'settings.general.title': 'General Settings',
    'settings.display.size': 'Display size',
    'settings.display.adjust': 'Adjust popup zoom/size',
    'settings.display.smaller': 'Smaller (A-)',
    'settings.display.larger': 'Larger (A+)',
    'settings.display.reset': 'Reset to 100%',
    'settings.display.description': 'Adjust the UI text size. Your preference is saved.',
    'settings.repair.browser': 'Repair Browser Launching',
    'settings.repair.description': 'If browsers aren\'t launching, click this to fix registry settings and permissions',
    'settings.show.wsl': 'Show WSL Ubuntu Linux and WSL Manager tabs',
    'settings.context.menu': 'Enable Context Menu',
    'settings.version.check': 'Check browser version every time',
    'settings.sandbox.context': 'Enable Windows Sandbox in context menu',
    'settings.check.interval': 'Check Interval (minutes)',
    'settings.interval.description': '1 - 60 Minutes Max',
    'settings.browser.paths': 'Browser Paths',
    'settings.wsl.settings': 'WSL Settings',
    'settings.save.paths': 'Save Path Info',
    'settings.test.notification': 'Test Notification',
    'settings.update.local': 'Update Local Browsers',
    'settings.update.wsl': 'Update WSL Browsers',
    'settings.view.eula': 'View EULA',
    'settings.language': 'Language',
    'settings.language.description': 'Select your preferred language',
    
    // Version Log
    'version.log.title': 'Version Update Log',
    'version.log.browser': 'Browser Name',
    'version.log.old': 'Old Version',
    'version.log.new': 'New Version',
    'version.log.date': 'Date/Time',
    'version.log.refresh': 'Refresh',
    'version.log.export': 'Export to CSV',
    'version.log.no.data': 'No version update logs available.',
    
    // WSL Manager
    'wsl.manager.title': 'WSL Manager',
    'wsl.manager.folder': 'WSL Instance Folder:',
    'wsl.manager.tar.path': 'WSL tar Image Path File:',
    'wsl.manager.username': 'WSL Username:',
    'wsl.manager.save': 'Save',
    'wsl.manager.password.protection': 'WSL Password Protection:',
    'wsl.manager.change.password': 'Change Password',
    'wsl.manager.password.required': 'Password required for all WSL operations',
    'wsl.manager.instances': 'WSL Instances',
    'wsl.manager.refresh': 'Refresh',
    'wsl.manager.export.tar': 'Export to TAR',
    'wsl.manager.create.new': 'Create New WSL Instance',
    'wsl.manager.create.description': 'Open WSL Instance Manager',
    'wsl.manager.make.default': 'Make Default',
    'wsl.manager.add.new': 'Create from tar file',
    'wsl.manager.delete': 'Delete',
    'wsl.manager.refresh.tar': 'Refresh from Tar file',
    'wsl.manager.rename': 'Rename',
    'wsl.manager.clone': 'Clone',
    
    // Search Settings
    'search.settings.title': 'Search Engine Settings',
    'search.settings.description': 'Control which search engines appear in the context menu when text is selected:',
    'search.engines.builtin': 'Built-in Search Engines',
    'search.engines.custom': 'Custom Search Engines',
    'search.engines.add.new': 'Add New',
    'search.youtube': 'YouTube Search',
    'search.google': 'Google Search',
    'search.duckduckgo': 'DuckDuckGo Search',
    'search.perplexity': 'Perplexity.ai Search',
    'search.chatgpt': 'ChatGPT Search',
    'search.googlemaps': 'Google Maps Search',
    'search.amazon': 'Amazon Search',
    'search.sandbox.link': 'Windows Sandbox (Link context menu)',
    
    // Help & Support
    'help.title': 'Help & Support',
    'help.license.status': 'Licensed Version',
    'help.manage.license': 'Manage License',
    'help.documentation': 'Documentation & Resources',
    'help.github': 'GitHub Repository',
    'help.user.guide': 'User Guide & Documentation',
    'help.report.issues': 'Report Issues',
    'help.support.channels': 'Support Channels',
    'help.email.support': 'Email Support:',
    'help.github.discussions': 'GitHub Discussions:',
    'help.join.community': 'Join our community discussions',
    'help.response.time': 'Response Time:',
    'help.response.description': 'We typically respond within 24-48 hours',
    'help.quick.links': 'Quick Links',
    'help.changelog': 'Changelog',
    'help.license.info': 'License Information',
    'help.contributing': 'Contributing Guidelines',
    'help.support.project': 'Support the Project',
    'help.support.description': 'If you find this extension helpful, consider supporting its development:',
    
    // Footer
    'footer.browser.downloads': 'Browser Downloads',
    'footer.edge.beta.dev': 'MS Edge Beta & Dev',
    'footer.chrome.beta': 'Chrome Beta',
    'footer.chrome.dev': 'Chrome Dev',
    'footer.firefox.developer': 'Firefox Developer',
    'footer.release.schedules': 'Release Schedules',
    'footer.edge.schedule': 'Edge Schedule',
    'footer.chrome.releases': 'Chrome Releases',
    'footer.firefox.releases': 'Firefox Releases',
    'footer.resources': 'Resources',
    'footer.github': 'GitHub',
    'footer.website': 'Website',
    'footer.support': 'Support',
    'footer.version': 'Version 3.0',
    'footer.build': 'Build 2025.11.08',
    'footer.copyright': '© 2025 Browser Launcher Pro. All rights reserved.',
    'footer.made.with.love': 'Made with ♥ for developers',
    'footer.trusted.users': 'Trusted by 10,000+ users',
    'footer.trial.version': 'TRIAL VERSION',
    'footer.days.remaining': 'DAYS REMAINING',
    'footer.active': 'Active',
    'footer.disclaimer': 'Browser icons and trademarks are the property of their respective companies. We are not affiliated with Microsoft, Google, Mozilla, Opera, or any other browser company.',
    
    // Messages and alerts
    'messages.settings.saved': 'Settings saved successfully!',
    'messages.settings.imported': 'Settings imported successfully!',
    'messages.error.importing': 'Error importing settings: Invalid JSON format.',
    'messages.fill.all.fields': 'Please fill out all required fields.',
    'messages.password.required': 'Password cannot be empty.',
    'messages.password.requirements': 'Password must be at least 8 characters long and contain at least one number.',
    'messages.select.instance': 'Please select an instance.',
    'messages.wsl.settings.saved': 'WSL settings saved successfully!',
    
    // Buttons
    'buttons.ok': 'OK',
    'buttons.cancel': 'Cancel',
    'buttons.close': 'Close',
    'buttons.save': 'Save',
    'buttons.export': 'Export',
    'buttons.import': 'Import',
    'buttons.refresh': 'Refresh',
    'buttons.activate': 'Activate License',
    'buttons.deactivate': 'Deactivate License',
    
    // Paths and labels
    'paths.stable': 'Stable Path:',
    'paths.beta': 'Beta Path:',
    'paths.dev': 'Dev Path:',
    'paths.not.available': 'Not Available',
    'paths.wsl.instance': 'WSL Instance:',
    'paths.wsl.scripts': 'WSL Scripts Path:',
    'paths.auto.discover': 'Auto Discover',
    'paths.powershell.user': 'PowerShell User:',
    'paths.use.powershell': 'Use this name to launch PowerShell',
    'paths.credential.manager': 'Also, add underlining user credentials in Windows Credential Manager'
  },
  
  'fr': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'Lancez et gérez plusieurs navigateurs sur Windows et WSL avec suivi de version',
    
    // Navigation tabs
    'nav.windows': 'Windows Local',
    'nav.wsl': 'WSL Ubuntu Linux',
    'nav.settings': 'Paramètres',
    'nav.versionLog': 'Journal des Versions',
    'nav.wslManager': 'Gestionnaire WSL',
    'nav.searchSettings': 'Paramètres de Recherche',
    'nav.helpSupport': 'Aide/Support',
    
    // Browser sections
    'browsers.edge.title': 'MICROSOFT EDGE (WINDOWS LOCAL)',
    'browsers.chrome.title': 'GOOGLE CHROME (WINDOWS LOCAL)',
    'browsers.stable': 'Stable',
    'browsers.beta': 'Bêta',
    'browsers.dev': 'Dév',
    'browsers.notFound': 'Non Trouvé',
    'browsers.watchVersions': 'Surveiller les changements de version',
    
    // WSL sections
    'wsl.edge.title': 'Microsoft Edge',
    'wsl.chrome.title': 'Google Chrome',
    'wsl.other.title': 'Autres Navigateurs',
    'wsl.tools.title': 'Outils WSL Ubuntu',
    'wsl.firefox': 'Firefox',
    'wsl.opera': 'Opera',
    'wsl.brave': 'Brave',
    'wsl.konsole': 'Lancer Konsole',
    'wsl.powershell': 'Lancer PowerShell',
    'wsl.sandbox': 'Lancer Win Sandbox',
    
    // Settings
    'settings.title': 'Paramètres',
    'settings.general.title': 'Paramètres Généraux',
    'settings.display.size': 'Taille d\'affichage',
    'settings.display.adjust': 'Ajuster le zoom/taille de la popup',
    'settings.display.smaller': 'Plus petit (A-)',
    'settings.display.larger': 'Plus grand (A+)',
    'settings.display.reset': 'Remettre à 100%',
    'settings.display.description': 'Ajustez la taille du texte de l\'interface. Votre préférence est sauvegardée.',
    'settings.repair.browser': 'Réparer le Lancement de Navigateur',
    'settings.repair.description': 'Si les navigateurs ne se lancent pas, cliquez ici pour corriger les paramètres de registre et les permissions',
    'settings.show.wsl': 'Afficher les onglets WSL Ubuntu Linux et Gestionnaire WSL',
    'settings.context.menu': 'Activer le Menu Contextuel',
    'settings.version.check': 'Vérifier la version du navigateur à chaque fois',
    'settings.sandbox.context': 'Activer Windows Sandbox dans le menu contextuel',
    'settings.check.interval': 'Intervalle de Vérification (minutes)',
    'settings.interval.description': '1 - 60 Minutes Max',
    'settings.browser.paths': 'Chemins des Navigateurs',
    'settings.wsl.settings': 'Paramètres WSL',
    'settings.save.paths': 'Sauvegarder Info Chemin',
    'settings.test.notification': 'Test de Notification',
    'settings.update.local': 'Mettre à Jour Navigateurs Locaux',
    'settings.update.wsl': 'Mettre à Jour Navigateurs WSL',
    'settings.view.eula': 'Voir CLUF',
    'settings.language': 'Langue',
    'settings.language.description': 'Sélectionnez votre langue préférée',
    
    // Version Log
    'version.log.title': 'Journal des Mises à Jour de Version',
    'version.log.browser': 'Nom du Navigateur',
    'version.log.old': 'Ancienne Version',
    'version.log.new': 'Nouvelle Version',
    'version.log.date': 'Date/Heure',
    'version.log.refresh': 'Actualiser',
    'version.log.export': 'Exporter en CSV',
    'version.log.no.data': 'Aucun journal de mise à jour de version disponible.',
    
    // Messages and alerts
    'messages.settings.saved': 'Paramètres sauvegardés avec succès!',
    'messages.settings.imported': 'Paramètres importés avec succès!',
    'messages.error.importing': 'Erreur lors de l\'importation des paramètres: Format JSON invalide.',
    'messages.fill.all.fields': 'Veuillez remplir tous les champs requis.',
    'messages.password.required': 'Le mot de passe ne peut pas être vide.',
    'messages.password.requirements': 'Le mot de passe doit contenir au moins 8 caractères et au moins un chiffre.',
    
    // Buttons
    'buttons.ok': 'OK',
    'buttons.cancel': 'Annuler',
    'buttons.close': 'Fermer',
    'buttons.save': 'Sauvegarder',
    'buttons.export': 'Exporter',
    'buttons.import': 'Importer'
  },
  
  'es': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'Lanza y gestiona múltiples navegadores en Windows y WSL con seguimiento de versiones',
    
    // Navigation tabs
    'nav.windows': 'Windows Local',
    'nav.wsl': 'WSL Ubuntu Linux',
    'nav.settings': 'Configuración',
    'nav.versionLog': 'Registro de Versiones',
    'nav.wslManager': 'Gestor WSL',
    'nav.searchSettings': 'Configuración de Búsqueda',
    'nav.helpSupport': 'Ayuda/Soporte',
    
    // Browser sections
    'browsers.edge.title': 'MICROSOFT EDGE (WINDOWS LOCAL)',
    'browsers.chrome.title': 'GOOGLE CHROME (WINDOWS LOCAL)',
    'browsers.stable': 'Estable',
    'browsers.beta': 'Beta',
    'browsers.dev': 'Dev',
    'browsers.notFound': 'No Encontrado',
    'browsers.watchVersions': 'Vigilar cambios de versión',
    
    // Settings
    'settings.title': 'Configuración',
    'settings.general.title': 'Configuración General',
    'settings.display.size': 'Tamaño de pantalla',
    'settings.language': 'Idioma',
    'settings.language.description': 'Selecciona tu idioma preferido',
    
    // Messages
    'messages.settings.saved': '¡Configuración guardada exitosamente!',
    'messages.password.required': 'La contraseña no puede estar vacía.',
    
    // Buttons
    'buttons.ok': 'Aceptar',
    'buttons.cancel': 'Cancelar',
    'buttons.close': 'Cerrar',
    'buttons.save': 'Guardar'
  },
  
  'de': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'Starten und verwalten Sie mehrere Browser auf Windows und WSL mit Versionsverfolgung',
    
    // Navigation tabs
    'nav.windows': 'Windows Lokal',
    'nav.wsl': 'WSL Ubuntu Linux',
    'nav.settings': 'Einstellungen',
    'nav.versionLog': 'Versions-Protokoll',
    'nav.wslManager': 'WSL-Manager',
    'nav.searchSettings': 'Such-Einstellungen',
    'nav.helpSupport': 'Hilfe/Support',
    
    // Browser sections
    'browsers.edge.title': 'MICROSOFT EDGE (WINDOWS LOKAL)',
    'browsers.chrome.title': 'GOOGLE CHROME (WINDOWS LOKAL)',
    'browsers.stable': 'Stabil',
    'browsers.beta': 'Beta',
    'browsers.dev': 'Dev',
    'browsers.notFound': 'Nicht Gefunden',
    
    // Settings
    'settings.title': 'Einstellungen',
    'settings.language': 'Sprache',
    'settings.language.description': 'Wählen Sie Ihre bevorzugte Sprache',
    
    // Messages
    'messages.settings.saved': 'Einstellungen erfolgreich gespeichert!',
    
    // Buttons
    'buttons.ok': 'OK',
    'buttons.cancel': 'Abbrechen',
    'buttons.save': 'Speichern'
  },
  
  'it': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'Avvia e gestisci più browser su Windows e WSL con tracciamento delle versioni',
    
    // Navigation
    'nav.settings': 'Impostazioni',
    'nav.helpSupport': 'Aiuto/Supporto',
    
    // Settings
    'settings.title': 'Impostazioni',
    'settings.language': 'Lingua',
    'settings.language.description': 'Seleziona la tua lingua preferita',
    
    // Messages
    'messages.settings.saved': 'Impostazioni salvate con successo!',
    
    // Buttons
    'buttons.ok': 'OK',
    'buttons.cancel': 'Annulla',
    'buttons.save': 'Salva'
  },
  
  'ar': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'إطلاق وإدارة متصفحات متعددة على Windows و WSL مع تتبع الإصدار',
    
    // Navigation
    'nav.windows': 'Windows محلي',
    'nav.settings': 'الإعدادات',
    'nav.helpSupport': 'المساعدة/الدعم',
    
    // Browser sections
    'browsers.stable': 'مستقر',
    'browsers.beta': 'بيتا',
    'browsers.dev': 'تطوير',
    'browsers.notFound': 'غير موجود',
    
    // Settings
    'settings.title': 'الإعدادات',
    'settings.language': 'اللغة',
    'settings.language.description': 'اختر لغتك المفضلة',
    
    // Messages
    'messages.settings.saved': 'تم حفظ الإعدادات بنجاح!',
    
    // Buttons
    'buttons.ok': 'موافق',
    'buttons.cancel': 'إلغاء',
    'buttons.save': 'حفظ'
  },
  
  'zh': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': '在 Windows 和 WSL 上启动和管理多个浏览器，支持版本跟踪',
    
    // Navigation
    'nav.windows': 'Windows 本地',
    'nav.settings': '设置',
    'nav.helpSupport': '帮助/支持',
    
    // Browser sections
    'browsers.stable': '稳定版',
    'browsers.beta': '测试版',
    'browsers.dev': '开发版',
    'browsers.notFound': '未找到',
    
    // Settings
    'settings.title': '设置',
    'settings.language': '语言',
    'settings.language.description': '选择您的首选语言',
    
    // Messages
    'messages.settings.saved': '设置保存成功！',
    
    // Buttons
    'buttons.ok': '确定',
    'buttons.cancel': '取消',
    'buttons.save': '保存'
  },
  
  'zh-TW': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': '在 Windows 和 WSL 上啟動和管理多個瀏覽器，支援版本追蹤',
    
    // Navigation
    'nav.settings': '設定',
    
    // Settings
    'settings.title': '設定',
    'settings.language': '語言',
    'settings.language.description': '選擇您的偏好語言',
    
    // Messages
    'messages.settings.saved': '設定儲存成功！',
    
    // Buttons
    'buttons.ok': '確定',
    'buttons.save': '儲存'
  },
  
  'ja': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'バージョン追跡機能付きで、WindowsおよびWSL上で複数のブラウザを起動・管理',
    
    // Navigation
    'nav.settings': '設定',
    
    // Settings
    'settings.title': '設定',
    'settings.language': '言語',
    'settings.language.description': 'お好みの言語を選択してください',
    
    // Messages
    'messages.settings.saved': '設定が正常に保存されました！',
    
    // Buttons
    'buttons.ok': 'OK',
    'buttons.save': '保存'
  },
  
  'ko': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': '버전 추적이 가능한 Windows 및 WSL에서 여러 브라우저 실행 및 관리',
    
    // Navigation
    'nav.settings': '설정',
    
    // Settings
    'settings.title': '설정',
    'settings.language': '언어',
    'settings.language.description': '선호하는 언어를 선택하세요',
    
    // Messages
    'messages.settings.saved': '설정이 성공적으로 저장되었습니다!',
    
    // Buttons
    'buttons.ok': '확인',
    'buttons.save': '저장'
  },
  
  'ru': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'Запуск и управление несколькими браузерами в Windows и WSL с отслеживанием версий',
    
    // Navigation
    'nav.settings': 'Настройки',
    
    // Settings
    'settings.title': 'Настройки',
    'settings.language': 'Язык',
    'settings.language.description': 'Выберите предпочитаемый язык',
    
    // Messages
    'messages.settings.saved': 'Настройки успешно сохранены!',
    
    // Buttons
    'buttons.ok': 'ОК',
    'buttons.save': 'Сохранить'
  },
  
  'pt': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'Lance e gerencie múltiplos navegadores no Windows e WSL com rastreamento de versões',
    
    // Navigation
    'nav.settings': 'Configurações',
    
    // Settings
    'settings.title': 'Configurações',
    'settings.language': 'Idioma',
    'settings.language.description': 'Selecione seu idioma preferido',
    
    // Messages
    'messages.settings.saved': 'Configurações salvas com sucesso!',
    
    // Buttons
    'buttons.ok': 'OK',
    'buttons.save': 'Salvar'
  },
  
  'nl': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'Start en beheer meerdere browsers op Windows en WSL met versietracking',
    
    // Navigation
    'nav.settings': 'Instellingen',
    
    // Settings
    'settings.title': 'Instellingen',
    'settings.language': 'Taal',
    'settings.language.description': 'Selecteer uw voorkeurstaal',
    
    // Messages
    'messages.settings.saved': 'Instellingen succesvol opgeslagen!',
    
    // Buttons
    'buttons.ok': 'OK',
    'buttons.save': 'Opslaan'
  },
  
  'pl': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'Uruchamiaj i zarządzaj wieloma przeglądarkami w Windows i WSL ze śledzeniem wersji',
    
    // Navigation
    'nav.settings': 'Ustawienia',
    
    // Settings
    'settings.title': 'Ustawienia',
    'settings.language': 'Język',
    'settings.language.description': 'Wybierz preferowany język',
    
    // Messages
    'messages.settings.saved': 'Ustawienia zapisane pomyślnie!',
    
    // Buttons
    'buttons.ok': 'OK',
    'buttons.save': 'Zapisz'
  },
  
  'he': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'הפעלה וניהול של דפדפנים מרובים ב-Windows וב-WSL עם מעקב גרסאות',
    
    // Navigation
    'nav.settings': 'הגדרות',
    
    // Settings
    'settings.title': 'הגדרות',
    'settings.language': 'שפה',
    'settings.language.description': 'בחר את השפה המועדפת עליך',
    
    // Messages
    'messages.settings.saved': 'ההגדרות נשמרו בהצלחה!',
    
    // Buttons
    'buttons.ok': 'אישור',
    'buttons.save': 'שמור'
  },
  
  'fa': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'راه‌اندازی و مدیریت چندین مرورگر در Windows و WSL با ردیابی نسخه',
    
    // Navigation
    'nav.settings': 'تنظیمات',
    
    // Settings
    'settings.title': 'تنظیمات',
    'settings.language': 'زبان',
    'settings.language.description': 'زبان مورد نظر خود را انتخاب کنید',
    
    // Messages
    'messages.settings.saved': 'تنظیمات با موفقیت ذخیره شد!',
    
    // Buttons
    'buttons.ok': 'تأیید',
    'buttons.save': 'ذخیره'
  },
  
  'tr': {
    // Header
    'header.title': 'Browser Launcher Pro',
    'header.subtitle': 'Windows ve WSL\'de sürüm takibi ile birden fazla tarayıcıyı başlatın ve yönetin',
    
    // Navigation
    'nav.settings': 'Ayarlar',
    
    // Settings
    'settings.title': 'Ayarlar',
    'settings.language': 'Dil',
    'settings.language.description': 'Tercih ettiğiniz dili seçin',
    
    // Messages
    'messages.settings.saved': 'Ayarlar başarıyla kaydedildi!',
    
    // Buttons
    'buttons.ok': 'Tamam',
    'buttons.save': 'Kaydet'
  }
};

// Current language
let currentLanguage = 'en';

/**
 * Initialize the internationalization system
 */
function initializeI18n() {
  // Load saved language preference or detect browser language
  chrome.storage.local.get(['selectedLanguage'], (result) => {
    if (result.selectedLanguage) {
      currentLanguage = result.selectedLanguage;
    } else {
      // Auto-detect browser language
      const browserLang = navigator.language || navigator.userLanguage;
      currentLanguage = detectSupportedLanguage(browserLang);
      // Save the detected language
      chrome.storage.local.set({ selectedLanguage: currentLanguage });
    }
    
    // Apply the language
    applyLanguage(currentLanguage);
    
    // Initialize language selector if it exists
    initializeLanguageSelector();
  });
}

/**
 * Detect if browser language is supported, fallback to English
 */
function detectSupportedLanguage(browserLang) {
  // Extract language code (e.g., 'en-US' -> 'en')
  const langCode = browserLang.split('-')[0];
  
  // Check if exact match exists (for Traditional Chinese)
  if (SUPPORTED_LANGUAGES[browserLang]) {
    return browserLang;
  }
  
  // Check if language code is supported
  if (SUPPORTED_LANGUAGES[langCode]) {
    return langCode;
  }
  
  // Fallback to English
  return 'en';
}

/**
 * Apply language translations to the UI
 */
function applyLanguage(langCode) {
  currentLanguage = langCode;
  const translations = TRANSLATIONS[langCode] || TRANSLATIONS['en'];
  
  // Update document direction for RTL languages
  const rtlLanguages = ['ar', 'he', 'fa'];
  if (rtlLanguages.includes(langCode)) {
    document.documentElement.dir = 'rtl';
    document.documentElement.lang = langCode;
  } else {
    document.documentElement.dir = 'ltr';
    document.documentElement.lang = langCode;
  }
  
  // Apply translations to elements with data-i18n attribute
  document.querySelectorAll('[data-i18n]').forEach(element => {
    const key = element.getAttribute('data-i18n');
    if (translations[key]) {
      // Handle different types of content
      if (element.hasAttribute('placeholder')) {
        element.placeholder = translations[key];
      } else if (element.hasAttribute('title')) {
        element.title = translations[key];
      } else if (element.tagName === 'INPUT' && element.type === 'submit') {
        element.value = translations[key];
      } else {
        element.textContent = translations[key];
      }
    }
  });
  
  // Apply translations to elements with data-i18n-html attribute (for HTML content)
  document.querySelectorAll('[data-i18n-html]').forEach(element => {
    const key = element.getAttribute('data-i18n-html');
    if (translations[key]) {
      element.innerHTML = translations[key];
    }
  });
  
  // Save the selected language
  chrome.storage.local.set({ selectedLanguage: langCode });
  
  // Trigger custom event for language change
  const event = new CustomEvent('languageChanged', { detail: { language: langCode } });
  document.dispatchEvent(event);
}

/**
 * Get translation for a specific key
 */
function t(key, langCode = null) {
  const lang = langCode || currentLanguage;
  const translations = TRANSLATIONS[lang] || TRANSLATIONS['en'];
  return translations[key] || key;
}

/**
 * Initialize language selector dropdown
 */
function initializeLanguageSelector() {
  const languageSelect = document.getElementById('language-select');
  if (!languageSelect) return;
  
  // Clear existing options
  languageSelect.innerHTML = '';
  
  // Group languages by region
  const languagesByRegion = {};
  Object.entries(SUPPORTED_LANGUAGES).forEach(([code, info]) => {
    if (!languagesByRegion[info.region]) {
      languagesByRegion[info.region] = [];
    }
    languagesByRegion[info.region].push({ code, ...info });
  });
  
    // Create optgroups for each region
    Object.entries(languagesByRegion).forEach(([region, languages]) => {
      const optgroup = document.createElement('optgroup');
      optgroup.label = region;
      
      languages.forEach(lang => {
        const option = document.createElement('option');
        option.value = lang.code;
        option.textContent = `[${lang.flag}] ${lang.nativeName}`;
        if (lang.code === currentLanguage) {
          option.selected = true;
        }
        optgroup.appendChild(option);
      });
      
      languageSelect.appendChild(optgroup);
    });  // Add event listener for language change
  languageSelect.addEventListener('change', (e) => {
    const selectedLang = e.target.value;
    applyLanguage(selectedLang);
  });
}

/**
 * Get current language code
 */
function getCurrentLanguage() {
  return currentLanguage;
}

/**
 * Get all supported languages
 */
function getSupportedLanguages() {
  return SUPPORTED_LANGUAGES;
}

/**
 * Get RTL languages list
 */
function isRTLLanguage(langCode = null) {
  const lang = langCode || currentLanguage;
  return ['ar', 'he', 'fa'].includes(lang);
}

// Export functions for use in other scripts
window.i18n = {
  initialize: initializeI18n,
  apply: applyLanguage,
  t: t,
  getCurrentLanguage: getCurrentLanguage,
  getSupportedLanguages: getSupportedLanguages,
  isRTL: isRTLLanguage,
  initializeLanguageSelector: initializeLanguageSelector
};

// Auto-initialize when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeI18n);
} else {
  initializeI18n();
}