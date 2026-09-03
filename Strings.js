// i18n. English (en), Norwegian Bokmål (nb), German (de), French (fr),
// Spanish (es), Portuguese (pt), Swedish (sv), Italian (it), and Finnish
// (fi) so far; to add another language, add another
// `languages.<code> = {...}` entry below with the same keys as `en` —
// any key it doesn't define falls back to English automatically, so a
// translation can be added incrementally rather than all at once.
//
// `<code>` is the language part of Qt.locale().name() (e.g. "en" from
// "en_US", "nb" from "nb_NO") — see currentLanguage() below.
var languages = {
  en: {
    barTooltip: "IMDb Search",
    searchPlaceholder: "Search movies & TV shows…",
    minChars: "Type at least 2 characters",
    searching: "Searching…",
    noResults: "No results",
    searchFailed: "Search failed — check your connection",
    hint: "Left click / Enter: open on IMDb\nRight click / Space: copy folder name\n↓ / ↑: select a result\nEsc: close the panel",
    copied: "Folder name copied.",
    moreResults: "Open search results on IMDb.com",
    shortcutsTooltip: "Show shortcuts",
    hideShortcutsTooltip: "Hide shortcuts"
  },
  nb: {
    barTooltip: "IMDb-søk",
    searchPlaceholder: "Søk etter filmer og TV-serier…",
    minChars: "Skriv minst 2 tegn",
    searching: "Søker…",
    noResults: "Ingen treff",
    searchFailed: "Søket feilet — sjekk internettforbindelsen",
    hint: "Venstreklikk / Enter: åpne på IMDb\nHøyreklikk / Mellomrom: kopier mappenavn\n↓ / ↑: velg et resultat\nEsc: lukk panelet",
    copied: "Mappenavn kopiert.",
    moreResults: "Åpne søkeresultater på IMDb.com",
    shortcutsTooltip: "Vis snarveier",
    hideShortcutsTooltip: "Skjul snarveier"
  },
  de: {
    barTooltip: "IMDb-Suche",
    searchPlaceholder: "Filme & Serien suchen…",
    minChars: "Mindestens 2 Zeichen eingeben",
    searching: "Suche läuft…",
    noResults: "Keine Treffer",
    searchFailed: "Suche fehlgeschlagen — Internetverbindung prüfen",
    hint: "Linksklick / Eingabe: auf IMDb öffnen\nRechtsklick / Leertaste: Ordnername kopieren\n↓ / ↑: Ergebnis auswählen\nEsc: Panel schließen",
    copied: "Ordnername kopiert.",
    moreResults: "Suchergebnisse auf IMDb.com öffnen",
    shortcutsTooltip: "Tastenkürzel anzeigen",
    hideShortcutsTooltip: "Tastenkürzel ausblenden"
  },
  fr: {
    barTooltip: "Recherche IMDb",
    searchPlaceholder: "Rechercher des films et séries…",
    minChars: "Saisissez au moins 2 caractères",
    searching: "Recherche…",
    noResults: "Aucun résultat",
    searchFailed: "Échec de la recherche — vérifiez votre connexion",
    hint: "Clic gauche / Entrée : ouvrir sur IMDb\nClic droit / Espace : copier le nom du dossier\n↓ / ↑ : sélectionner un résultat\nÉchap : fermer le panneau",
    copied: "Nom du dossier copié.",
    moreResults: "Ouvrir les résultats de recherche sur IMDb.com",
    shortcutsTooltip: "Afficher les raccourcis",
    hideShortcutsTooltip: "Masquer les raccourcis"
  },
  es: {
    barTooltip: "Búsqueda en IMDb",
    searchPlaceholder: "Buscar películas y series…",
    minChars: "Escribe al menos 2 caracteres",
    searching: "Buscando…",
    noResults: "Sin resultados",
    searchFailed: "Error en la búsqueda — comprueba tu conexión",
    hint: "Clic izquierdo / Intro: abrir en IMDb\nClic derecho / Espacio: copiar nombre de carpeta\n↓ / ↑: seleccionar un resultado\nEsc: cerrar el panel",
    copied: "Nombre de carpeta copiado.",
    moreResults: "Abrir resultados de búsqueda en IMDb.com",
    shortcutsTooltip: "Mostrar atajos",
    hideShortcutsTooltip: "Ocultar atajos"
  },
  pt: {
    barTooltip: "Pesquisa IMDb",
    searchPlaceholder: "Pesquisar filmes e séries…",
    minChars: "Digite pelo menos 2 caracteres",
    searching: "Pesquisando…",
    noResults: "Nenhum resultado",
    searchFailed: "Falha na pesquisa — verifique sua conexão",
    hint: "Clique esquerdo / Enter: abrir no IMDb\nClique direito / Espaço: copiar nome da pasta\n↓ / ↑: selecionar um resultado\nEsc: fechar o painel",
    copied: "Nome da pasta copiado.",
    moreResults: "Abrir resultados de pesquisa no IMDb.com",
    shortcutsTooltip: "Mostrar atalhos",
    hideShortcutsTooltip: "Ocultar atalhos"
  },
  sv: {
    barTooltip: "IMDb-sökning",
    searchPlaceholder: "Sök efter filmer och TV-serier…",
    minChars: "Skriv minst 2 tecken",
    searching: "Söker…",
    noResults: "Inga träffar",
    searchFailed: "Sökningen misslyckades — kontrollera din anslutning",
    hint: "Vänsterklick / Enter: öppna på IMDb\nHögerklick / Mellanslag: kopiera mappnamn\n↓ / ↑: välj ett resultat\nEsc: stäng panelen",
    copied: "Mappnamn kopierat.",
    moreResults: "Öppna sökresultat på IMDb.com",
    shortcutsTooltip: "Visa genvägar",
    hideShortcutsTooltip: "Dölj genvägar"
  },
  it: {
    barTooltip: "Ricerca IMDb",
    searchPlaceholder: "Cerca film e serie TV…",
    minChars: "Digita almeno 2 caratteri",
    searching: "Ricerca in corso…",
    noResults: "Nessun risultato",
    searchFailed: "Ricerca non riuscita — controlla la connessione",
    hint: "Clic sinistro / Invio: apri su IMDb\nClic destro / Spazio: copia nome cartella\n↓ / ↑: seleziona un risultato\nEsc: chiudi il pannello",
    copied: "Nome cartella copiato.",
    moreResults: "Apri i risultati di ricerca su IMDb.com",
    shortcutsTooltip: "Mostra scorciatoie",
    hideShortcutsTooltip: "Nascondi scorciatoie"
  },
  fi: {
    barTooltip: "IMDb-haku",
    searchPlaceholder: "Hae elokuvia ja sarjoja…",
    minChars: "Kirjoita vähintään 2 merkkiä",
    searching: "Haetaan…",
    noResults: "Ei tuloksia",
    searchFailed: "Haku epäonnistui — tarkista verkkoyhteytesi",
    hint: "Vasen klikkaus / Enter: avaa IMDb:ssä\nOikea klikkaus / Välilyönti: kopioi kansion nimi\n↓ / ↑: valitse tulos\nEsc: sulje paneeli",
    copied: "Kansion nimi kopioitu.",
    moreResults: "Avaa hakutulokset IMDb.comissa",
    shortcutsTooltip: "Näytä pikanäppäimet",
    hideShortcutsTooltip: "Piilota pikanäppäimet"
  }
}
// Qt.locale().name() can report the deprecated macrolanguage code "no"
// instead of "nb" (Bokmål) depending on how the system locale was set —
// point it at the same table rather than falling back to English.
languages.no = languages.nb

// The system's current language, following Qt.locale() (which reflects the
// desktop/session locale, e.g. LANG) — falls back to "en" if the system
// language has no translation table above.
function currentLanguage() {
  try {
    var name = String(Qt.locale().name || "")
    var lang = name.split("_")[0].toLowerCase()
    return languages[lang] ? lang : "en"
  } catch (e) {
    return "en"
  }
}

// Translated string for `key` in the system's language, falling back to
// English, then to the key itself if even English is somehow missing it.
function t(key) {
  var table = languages[currentLanguage()] || languages.en
  if (table && table[key] !== undefined) return table[key]
  if (languages.en && languages.en[key] !== undefined) return languages.en[key]
  return key
}
