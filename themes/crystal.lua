--[[
* themes/crystal.lua — omni's "Crystal & Gold" look: deep navy glass, gold-tinted buttons and headers.
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
    windowBg         = { 0.035, 0.050, 0.120, 0.95 },
    windowTitleBg    = { 0.07, 0.09, 0.20, 0.95 },
    windowTitleBgAct = { 0.10, 0.13, 0.27, 0.98 },
    windowBorder     = { 0.90, 0.77, 0.42, 0.35 },  -- subtle border
    childBg          = { 0.050, 0.070, 0.150, 0.55 },   -- lower alpha for layered depth
    tooltipBg        = { 0.035, 0.050, 0.120, 0.98 },
    panelBg          = { 0.040, 0.055, 0.125, 0.95 },

    -- Frame / input — slightly lifted from bg
    frameBg          = { 0.060, 0.080, 0.150, 1.00 },
    frameBgHovered   = { 0.100, 0.120, 0.220, 1.00 },

    -- Scrollbar — thin, unobtrusive
    scrollbarBg      = { 0.00, 0.00, 0.00, 0.00 },
    scrollbarGrab    = { 0.90, 0.77, 0.42, 0.35 },
    scrollbarHover   = { 0.90, 0.77, 0.42, 0.55 },
    scrollbarActive  = { 0.90, 0.77, 0.42, 0.80 },

    -- Tabs — clearer active state
    tab              = { 0.00, 0.00, 0.00, 0.00 },
    tabHovered       = { 0.90, 0.77, 0.42, 0.16 },
    tabActive        = { 0.90, 0.77, 0.42, 0.28 },

    -- Selectable / header
    selectHeader     = { 0.90, 0.77, 0.42, 0.14 },
    selectHovered    = { 0.90, 0.77, 0.42, 0.22 },
    selectActive     = { 0.90, 0.77, 0.42, 0.30 },

    -- Text — stronger hierarchy
    header           = { 0.95, 0.83, 0.50, 1.00 },
    accent           = { 0.90, 0.77, 0.42, 1.00 },
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
    headerBg         = { 0.070, 0.090, 0.180, 0.95 },
    catBtnBg         = { 0.070, 0.090, 0.180, 0.95 },
    selected         = { 0.90, 0.77, 0.42, 0.18 },
    searchHint       = { 0.38, 0.38, 0.44, 1.00 },
    breadcrumb       = { 0.80, 0.74, 0.55, 1.00 },

    -- Buttons: primary action — slightly more vibrant
    btnPrimary       = { 0.62, 0.50, 0.22, 0.95 },
    btnPrimaryHover  = { 0.74, 0.61, 0.30, 1.00 },
    btnPrimaryActive = { 0.90, 0.77, 0.42, 1.00 },
    btnDimmed        = { 0.18, 0.16, 0.22, 0.40 },

    -- Buttons: feature (secondary)
    btnFeature       = { 0.90, 0.77, 0.42, 0.08 },
    btnFeatureHover  = { 0.90, 0.77, 0.42, 0.18 },
    btnFeatureActive = { 0.90, 0.77, 0.42, 0.28 },

    -- Buttons: positive (store/confirm)
    btnPositive      = { 0.18, 0.40, 0.22, 0.85 },
    btnPositiveHover = { 0.24, 0.52, 0.28, 0.90 },
    btnPositiveActive= { 0.30, 0.62, 0.35, 1.00 },

    -- Buttons: back/cancel
    btnBack          = { 0.90, 0.77, 0.42, 0.08 },
    btnBackHover     = { 0.90, 0.77, 0.42, 0.18 },
    btnBackActive    = { 0.90, 0.77, 0.42, 0.28 },

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
