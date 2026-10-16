--[[
* themes/omni.lua — omni's "Vana'diel classic" theme: navy panels, gold trim.
* (A recolour of Trove's default theme.)
*
* Copy this file and modify to create custom themes.
* Set the theme in trove.lua: local THEME = 'mytheme'
* Place your theme at: themes/mytheme.lua
*
* Colors are RGBA tables: { R, G, B, A } where each value is 0.0 to 1.0
]]--

return {
    -- Window chrome — deeper background, subtle blue tint for depth
    windowBg         = { 0.045, 0.06, 0.14, 0.95 },
    windowTitleBg    = { 0.07, 0.09, 0.20, 0.95 },
    windowTitleBgAct = { 0.10, 0.13, 0.27, 0.98 },
    windowBorder     = { 0.79, 0.69, 0.42, 0.35 },  -- subtle border
    childBg          = { 0.09, 0.12, 0.25, 0.40 },   -- lower alpha for layered depth
    tooltipBg        = { 0.05, 0.07, 0.15, 0.97 },
    panelBg          = { 0.06, 0.08, 0.17, 0.95 },

    -- Frame / input — slightly lifted from bg
    frameBg          = { 0.10, 0.13, 0.27, 0.90 },
    frameBgHovered   = { 0.16, 0.20, 0.38, 0.90 },

    -- Scrollbar — thin, unobtrusive
    scrollbarBg      = { 0.03, 0.04, 0.10, 0.30 },
    scrollbarGrab    = { 0.60, 0.51, 0.27, 0.60 },
    scrollbarHover   = { 0.79, 0.69, 0.42, 0.75 },
    scrollbarActive  = { 0.91, 0.84, 0.59, 0.90 },

    -- Tabs — clearer active state
    tab              = { 0.10, 0.13, 0.27, 0.85 },
    tabHovered       = { 0.24, 0.30, 0.52, 0.90 },
    tabActive        = { 0.60, 0.51, 0.27, 1.00 },

    -- Selectable / header
    selectHeader     = { 0.20, 0.25, 0.46, 0.50 },
    selectHovered    = { 0.28, 0.34, 0.58, 0.45 },
    selectActive     = { 0.36, 0.43, 0.68, 0.65 },

    -- Text — stronger hierarchy
    header           = { 0.91, 0.84, 0.59, 1.00 },
    accent           = { 0.79, 0.69, 0.42, 1.00 },
    dimmed           = { 0.58, 0.62, 0.76, 1.00 },
    white            = { 0.95, 0.95, 0.97, 1.00 },
    desc             = { 0.70, 0.73, 0.84, 1.00 },
    yellow           = { 1.00, 0.92, 0.55, 1.00 },
    blue             = { 0.55, 0.75, 1.00, 1.00 },
    green            = { 0.50, 0.88, 0.50, 1.00 },
    red              = { 1.00, 0.50, 0.50, 1.00 },

    -- Status
    statusOk         = { 0.50, 0.88, 0.50, 1.00 },
    statusErr        = { 1.00, 0.50, 0.50, 1.00 },
    statusWarn       = { 1.00, 0.85, 0.30, 1.00 },

    -- Items
    rare             = { 1.00, 0.85, 0.30, 1.00 },
    ex               = { 0.40, 0.88, 0.40, 1.00 },
    rareBg           = { 0.40, 0.35, 0.10, 0.70 },
    exBg             = { 0.10, 0.32, 0.15, 0.70 },
    qty              = { 0.91, 0.84, 0.59, 1.00 },
    qtyLow           = { 1.00, 0.70, 0.40, 1.00 },
    empty            = { 0.58, 0.62, 0.76, 0.75 },
    slotText         = { 0.78, 0.78, 0.84, 1.00 },
    jobText          = { 0.82, 0.78, 0.92, 1.00 },

    -- Categories & navigation
    category         = { 0.50, 0.78, 0.50, 1.00 },
    headerBg         = { 0.10, 0.13, 0.27, 0.90 },
    catBtnBg         = { 0.09, 0.12, 0.25, 0.90 },
    selected         = { 0.18, 0.23, 0.43, 0.85 },
    searchHint       = { 0.38, 0.38, 0.44, 1.00 },
    breadcrumb       = { 0.80, 0.74, 0.55, 1.00 },

    -- Buttons: primary action — slightly more vibrant
    btnPrimary       = { 0.45, 0.38, 0.18, 0.90 },
    btnPrimaryHover  = { 0.60, 0.51, 0.27, 0.95 },
    btnPrimaryActive = { 0.79, 0.69, 0.42, 1.00 },
    btnDimmed        = { 0.18, 0.16, 0.22, 0.40 },

    -- Buttons: feature (secondary)
    btnFeature       = { 0.13, 0.17, 0.34, 0.90 },
    btnFeatureHover  = { 0.24, 0.30, 0.52, 0.95 },
    btnFeatureActive = { 0.32, 0.39, 0.64, 1.00 },

    -- Buttons: positive (store/confirm)
    btnPositive      = { 0.18, 0.40, 0.22, 0.85 },
    btnPositiveHover = { 0.24, 0.52, 0.28, 0.90 },
    btnPositiveActive= { 0.30, 0.62, 0.35, 1.00 },

    -- Buttons: back/cancel
    btnBack          = { 0.13, 0.17, 0.34, 0.85 },
    btnBackHover     = { 0.24, 0.30, 0.52, 0.90 },
    btnBackActive    = { 0.32, 0.39, 0.64, 0.95 },

    -- Currency / Points
    currencyName     = { 0.95, 0.88, 0.65, 1.00 },
    currencyTotal    = { 1.00, 0.95, 0.72, 1.00 },
    currencyBrk      = { 0.60, 0.60, 0.68, 1.00 },
    pointsGroup      = { 0.91, 0.84, 0.59, 1.00 },
    pointsLabel      = { 0.88, 0.88, 0.92, 1.00 },
    pointsValue      = { 1.00, 0.95, 0.72, 1.00 },

    -- VNM-specific (plugins can extend the theme)
    alertGlow        = { 1.00, 0.85, 0.30, 1.00 },
    ownedTick        = { 0.40, 0.88, 0.40, 1.00 },
    notOwned         = { 0.28, 0.18, 0.18, 1.00 },
    dimText          = { 0.45, 0.45, 0.50, 1.00 },
};
