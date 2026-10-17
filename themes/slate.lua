--[[
* themes/crystal.lua — omni's "Slate Minimal" theme (generated from blackgold.lua; colours match THEMES in omni.lua).
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
    windowBg         = { 0.083, 0.086, 0.094, 0.97 },
    windowTitleBg    = { 0.116, 0.120, 0.135, 0.95 },
    windowTitleBgAct = { 0.145, 0.150, 0.166, 0.98 },
    windowBorder     = { 0.194, 0.200, 0.218, 1.00 },  -- subtle border
    childBg          = { 0.060, 0.062, 0.069, 1.00 },   -- lower alpha for layered depth
    tooltipBg        = { 0.035, 0.050, 0.120, 0.98 },
    panelBg          = { 0.073, 0.075, 0.083, 0.97 },

    -- Frame / input — slightly lifted from bg
    frameBg          = { 0.145, 0.150, 0.172, 1.00 },
    frameBgHovered   = { 0.194, 0.200, 0.229, 1.00 },

    -- Scrollbar — thin, unobtrusive
    scrollbarBg      = { 0.000, 0.000, 0.000, 0.00 },
    scrollbarGrab    = { 0.370, 0.830, 0.780, 0.35 },
    scrollbarHover   = { 0.370, 0.830, 0.780, 0.55 },
    scrollbarActive  = { 0.370, 0.830, 0.780, 0.80 },

    -- Tabs — clearer active state
    tab              = { 0.000, 0.000, 0.000, 0.00 },
    tabHovered       = { 0.370, 0.830, 0.780, 0.16 },
    tabActive        = { 0.302, 0.678, 0.637, 1.00 },

    -- Selectable / header
    selectHeader     = { 0.370, 0.830, 0.780, 0.14 },
    selectHovered    = { 0.370, 0.830, 0.780, 0.22 },
    selectActive     = { 0.370, 0.830, 0.780, 0.30 },

    -- Text — stronger hierarchy
    header           = { 0.399, 0.894, 0.840, 1.00 },
    accent           = { 0.370, 0.830, 0.780, 1.00 },
    dimmed           = { 0.550, 0.550, 0.580, 1.00 },
    white            = { 0.950, 0.950, 0.970, 1.00 },
    desc             = { 0.700, 0.700, 0.730, 1.00 },
    yellow           = { 0.434, 0.973, 0.915, 1.00 },
    blue             = { 0.550, 0.750, 1.000, 1.00 },
    green            = { 0.500, 0.880, 0.500, 1.00 },
    red              = { 1.000, 0.500, 0.500, 1.00 },

    -- Status
    statusOk         = { 0.500, 0.880, 0.500, 1.00 },
    statusErr        = { 1.000, 0.500, 0.500, 1.00 },
    statusWarn       = { 0.400, 0.898, 0.844, 1.00 },

    -- Items
    rare             = { 0.400, 0.898, 0.844, 1.00 },
    ex               = { 0.400, 0.880, 0.400, 1.00 },
    rareBg           = { 0.400, 0.350, 0.100, 0.70 },
    exBg             = { 0.100, 0.320, 0.150, 0.70 },
    qty              = { 0.401, 0.898, 0.844, 1.00 },
    qtyLow           = { 0.364, 0.815, 0.766, 1.00 },
    empty            = { 0.550, 0.550, 0.580, 0.75 },
    slotText         = { 0.780, 0.780, 0.840, 1.00 },
    jobText          = { 0.820, 0.780, 0.920, 1.00 },

    -- Categories & navigation
    category         = { 0.500, 0.780, 0.500, 1.00 },
    headerBg         = { 0.145, 0.150, 0.172, 1.00 },
    catBtnBg         = { 0.145, 0.150, 0.172, 1.00 },
    selected         = { 0.204, 0.210, 0.239, 1.00 },
    searchHint       = { 0.380, 0.380, 0.440, 1.00 },
    breadcrumb       = { 0.354, 0.795, 0.747, 1.00 },

    -- Buttons: primary action — slightly more vibrant
    btnPrimary       = { 0.302, 0.678, 0.637, 1.00 },
    btnPrimaryHover  = { 0.340, 0.762, 0.716, 1.00 },
    btnPrimaryActive = { 0.370, 0.830, 0.780, 1.00 },
    btnDimmed        = { 0.145, 0.150, 0.166, 0.50 },

    -- Buttons: feature (secondary)
    btnFeature       = { 0.145, 0.150, 0.172, 1.00 },
    btnFeatureHover  = { 0.204, 0.210, 0.239, 1.00 },
    btnFeatureActive = { 0.302, 0.678, 0.637, 1.00 },

    -- Buttons: positive (store/confirm)
    btnPositive      = { 0.180, 0.400, 0.220, 0.85 },
    btnPositiveHover = { 0.240, 0.520, 0.280, 0.90 },
    btnPositiveActive= { 0.300, 0.620, 0.350, 1.00 },

    -- Buttons: back/cancel
    btnBack          = { 0.145, 0.150, 0.172, 1.00 },
    btnBackHover     = { 0.204, 0.210, 0.239, 1.00 },
    btnBackActive    = { 0.302, 0.678, 0.637, 1.00 },

    -- Currency / Points
    currencyName     = { 0.421, 0.944, 0.887, 1.00 },
    currencyTotal    = { 0.452, 1.000, 0.952, 1.00 },
    currencyBrk      = { 0.600, 0.600, 0.680, 1.00 },
    pointsGroup      = { 0.401, 0.898, 0.844, 1.00 },
    pointsLabel      = { 0.880, 0.880, 0.920, 1.00 },
    pointsValue      = { 0.452, 1.000, 0.952, 1.00 },

    -- VNM-specific (plugins can extend the theme)
    alertGlow        = { 0.400, 0.898, 0.844, 1.00 },
    ownedTick        = { 0.400, 0.880, 0.400, 1.00 },
    notOwned         = { 0.280, 0.180, 0.180, 1.00 },
    dimText          = { 0.450, 0.450, 0.500, 1.00 },
};
