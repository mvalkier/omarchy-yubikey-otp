.pragma library

// Brand icons per OTP issuer. Paths and colours come from Simple Icons 16.34.0
// (CC0); each path is drawn in a 24×24 box. An issuer is recognized by its
// normalized name: lower case, letters and digits only. `names` catches
// variants people use as the issuer.
//
// An issuer not listed here gets a tile with its first letter.
var BRANDS = [
  {
    names: ["autodesk"],
    color: "#000000",
    path: "m.129 20.202 14.7-9.136h7.625c.235 0 .445.188.445.445 0 .21-.092.305-.21.375l-7.222 4.323c-.47.283-.633.845-.633 1.265l-.008 2.725H24V4.362a.561.561 0 0 0-.585-.562h-8.752L0 12.893V20.2h.129z"
  },
  {
    names: ["bambulab", "bambulabs", "bambu"],
    color: "#00AE42",
    path: "M12.662 24V8.959l8.535 3.369V24zm-9.859-.003v-7.521l8.534-3.371-.001 10.892zM2.803 0h8.533l.001 11.672-8.534 3.369zm9.859 0h8.535v10.892l-8.535-3.371z"
  },
  {
    names: ["jetbrains"],
    color: "#000000",
    path: "M2.345 23.997A2.347 2.347 0 0 1 0 21.652V10.988C0 9.665.535 8.37 1.473 7.433l5.965-5.961A5.01 5.01 0 0 1 10.989 0h10.666A2.347 2.347 0 0 1 24 2.345v10.664a5.056 5.056 0 0 1-1.473 3.554l-5.965 5.965A5.017 5.017 0 0 1 13.007 24v-.003H2.345Zm8.969-6.854H5.486v1.371h5.828v-1.371ZM3.963 6.514h13.523v13.519l4.257-4.257a3.936 3.936 0 0 0 1.146-2.767V2.345c0-.678-.552-1.234-1.234-1.234H10.989a3.897 3.897 0 0 0-2.767 1.145L3.963 6.514Zm-.192.192L2.256 8.22a3.944 3.944 0 0 0-1.145 2.768v10.664c0 .678.552 1.234 1.234 1.234h10.666a3.9 3.9 0 0 0 2.767-1.146l1.512-1.511H3.771V6.706Z"
  }
]

// Tile colours for issuers without a brand icon. Medium saturation, so white
// letters stay readable on them, on a light and a dark panel alike.
var PALETTE = ["#c0504d", "#d17a22", "#9a8a1f", "#4e9a3a", "#2e8b8b", "#3a78c2", "#7a5cc2", "#b04f8f"]

function normalize(issuer) {
  return String(issuer || "").toLowerCase().replace(/[^a-z0-9]/g, "")
}

function findBrand(issuer) {
  var key = normalize(issuer)
  if (key === "") return null
  for (var i = 0; i < BRANDS.length; i++) {
    if (BRANDS[i].names.indexOf(key) >= 0) return BRANDS[i]
  }
  return null
}

// Relative luminance (WCAG) of a "#rrggbb" colour.
function luminance(hex) {
  var channels = [1, 3, 5].map(function (i) {
    var c = parseInt(hex.substr(i, 2), 16) / 255
    return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
  })
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
}

// {tile, foreground, path, letter}. With a dark brand colour (black for
// Autodesk and JetBrains) the tile is white with the logo in the brand colour,
// as those brands show themselves; otherwise the tile is the brand colour with
// a white logo.
function icon(issuer) {
  var brand = findBrand(issuer)
  if (brand) {
    var dark = luminance(brand.color) < 0.2
    return {
      tile: dark ? "#ffffff" : brand.color,
      foreground: dark ? brand.color : "#ffffff",
      path: brand.path,
      letter: ""
    }
  }
  var key = normalize(issuer)
  var hash = 0
  for (var i = 0; i < key.length; i++) hash = (hash * 31 + key.charCodeAt(i)) >>> 0
  return {
    tile: PALETTE[hash % PALETTE.length],
    foreground: "#ffffff",
    path: "",
    letter: key === "" ? "?" : key.charAt(0).toUpperCase()
  }
}

// A code in groups of three ("806 027"). A length not divisible by three
// (8 digits on some accounts) is split into two halves.
function group(code) {
  var s = String(code || "")
  if (s.length <= 4) return s
  if (s.length % 3 !== 0) {
    var half = Math.floor(s.length / 2)
    return s.substr(0, half) + " " + s.substr(half)
  }
  return s.match(/.{3}/g).join(" ")
}
