--[[
* themes/crystal.lua — omni's "Frost" theme (generated from blackgold.lua; colours match THEMES in omni.lua).
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
    windowBg         = { 0.081, 0.086, 0.101, 0.97 },
    windowTitleBg    = { 0.113, 0.120, 0.146, 0.95 },
    windowTitleBgAct = { 0.141, 0.150, 0.179, 0.98 },
    windowBorder     = { 0.188, 0.200, 0.235, 1.00 },  -- subtle border
    childBg          = { 0.058, 0.062, 0.074, 1.00 },   -- lower alpha for layered depth
    tooltipBg        = { 0.035, 0.050, 0.120, 0.98 },
    panelBg          = { 0.070, 0.075, 0.090, 0.97 },

    -- Frame / input — slightly lifted from bg
    frameBg          = { 0.141, 0.150, 0.185, 1.00 },
    frameBgHovered   = { 0.188, 0.200, 0.246, 1.00 },

    -- Scrollbar — thin, unobtrusive
    scrollbarBg      = { 0.000, 0.000, 0.000, 0.00 },
    scrollbarGrab    = { 0.550, 0.800, 1.000, 0.35 },
    scrollbarHover   = { 0.550, 0.800, 1.000, 0.55 },
    scrollbarActive  = { 0.550, 0.800, 1.000, 0.80 },

    -- Tabs — clearer active state
    tab              = { 0.000, 0.000, 0.000, 0.00 },
    tabHovered       = { 0.550, 0.800, 1.000, 0.16 },
    tabActive        = { 0.449, 0.654, 0.817, 1.00 },

    -- Selectable / header
    selectHeader     = { 0.550, 0.800, 1.000, 0.14 },
    selectHovered    = { 0.550, 0.800, 1.000, 0.22 },
    selectActive     = { 0.550, 0.800, 1.000, 0.30 },

    -- Text — stronger hierarchy
    header           = { 0.592, 0.862, 1.000, 1.00 },
    accent           = { 0.550, 0.800, 1.000, 1.00 },
    dimmed           = { 0.550, 0.550, 0.580, 1.00 },
    white            = { 0.950, 0.950, 0.970, 1.00 },
    desc             = { 0.700, 0.700, 0.730, 1.00 },
    yellow           = { 0.645, 0.938, 1.000, 1.00 },
    blue             = { 0.550, 0.750, 1.000, 1.00 },
    green            = { 0.500, 0.880, 0.500, 1.00 },
    red              = { 1.000, 0.500, 0.500, 1.00 },

    -- Status
    statusOk         = { 0.500, 0.880, 0.500, 1.00 },
    statusErr        = { 1.000, 0.500, 0.500, 1.00 },
    statusWarn       = { 0.595, 0.866, 1.000, 1.00 },

    -- Items
    rare             = { 0.595, 0.866, 1.000, 1.00 },
    ex               = { 0.400, 0.880, 0.400, 1.00 },
    rareBg           = { 0.400, 0.350, 0.100, 0.70 },
    exBg             = { 0.100, 0.320, 0.150, 0.70 },
    qty              = { 0.595, 0.866, 1.000, 1.00 },
    qtyLow           = { 0.540, 0.786, 0.982, 1.00 },
    empty            = { 0.550, 0.550, 0.580, 0.75 },
    slotText         = { 0.780, 0.780, 0.840, 1.00 },
    jobText          = { 0.820, 0.780, 0.920, 1.00 },

    -- Categories & navigation
    category         = { 0.500, 0.780, 0.500, 1.00 },
    headerBg         = { 0.141, 0.150, 0.185, 1.00 },
    catBtnBg         = { 0.141, 0.150, 0.185, 1.00 },
    selected         = { 0.197, 0.210, 0.258, 1.00 },
    searchHint       = { 0.380, 0.380, 0.440, 1.00 },
    breadcrumb       = { 0.527, 0.766, 0.957, 1.00 },

    -- Buttons: primary action — slightly more vibrant
    btnPrimary       = { 0.449, 0.654, 0.817, 1.00 },
    btnPrimaryHover  = { 0.505, 0.734, 0.918, 1.00 },
    btnPrimaryActive = { 0.550, 0.800, 1.000, 1.00 },
    btnDimmed        = { 0.141, 0.150, 0.179, 0.50 },

    -- Buttons: feature (secondary)
    btnFeature       = { 0.141, 0.150, 0.185, 1.00 },
    btnFeatureHover  = { 0.197, 0.210, 0.258, 1.00 },
    btnFeatureActive = { 0.449, 0.654, 0.817, 1.00 },

    -- Buttons: positive (store/confirm)
    btnPositive      = { 0.180, 0.400, 0.220, 0.85 },
    btnPositiveHover = { 0.240, 0.520, 0.280, 0.90 },
    btnPositiveActive= { 0.300, 0.620, 0.350, 1.00 },

    -- Buttons: back/cancel
    btnBack          = { 0.141, 0.150, 0.185, 1.00 },
    btnBackHover     = { 0.197, 0.210, 0.258, 1.00 },
    btnBackActive    = { 0.449, 0.654, 0.817, 1.00 },

    -- Currency / Points
    currencyName     = { 0.626, 0.910, 1.000, 1.00 },
    currencyTotal    = { 0.671, 0.977, 1.000, 1.00 },
    currencyBrk      = { 0.600, 0.600, 0.680, 1.00 },
    pointsGroup      = { 0.595, 0.866, 1.000, 1.00 },
    pointsLabel      = { 0.880, 0.880, 0.920, 1.00 },
    pointsValue      = { 0.671, 0.977, 1.000, 1.00 },

    -- VNM-specific (plugins can extend the theme)
    alertGlow        = { 0.595, 0.866, 1.000, 1.00 },
    ownedTick        = { 0.400, 0.880, 0.400, 1.00 },
    notOwned         = { 0.280, 0.180, 0.180, 1.00 },
    dimText          = { 0.450, 0.450, 0.500, 1.00 },
};
