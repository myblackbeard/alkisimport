SET client_encoding TO 'UTF8';
SET search_path = :"alkis_schema", :"parent_schema", :"postgis_schema", public;

--
-- Sonstiges Bauwerk oder sonstige Einrichtung (51109)
--

SELECT 'Sonstige Bauwerke oder Einrichtungen werden verarbeitet (HBDKOM).';


-- Flächen
INSERT INTO po_polygons(gml_id,thema,layer,polygon,signaturnummer,modell)
SELECT
	gml_id,
	'Gebäude' AS thema,
	'ks_sonstigesbauwerkodersonstigeeinrichtung' AS layer,
	polygon,
	signaturnummer,
	modell
FROM (
	SELECT
		o.gml_id,
		st_multi(wkb_geometry) AS polygon,
		CASE
		WHEN bauwerksfunktion=1620                THEN '1305'
		WHEN bauwerksfunktion IN (1640,1655,1660) THEN '2507'
		WHEN bauwerksfunktion IN (1780,1782)      THEN '1525'
		END AS signaturnummer,
		advstandardmodell||sonstigesmodell AS modell
	FROM ks_sonstigesbauwerkodersonstigeeinrichtung o
	WHERE geometrytype(wkb_geometry) IN ('POLYGON','MULTIPOLYGON')
	  AND endet IS NULL
	  AND bauwerksfunktion=1620
	  AND 'HBDKOM' = ANY(sonstigesmodell)
) AS o
WHERE NOT signaturnummer IS NULL ;

-- TODO: Stufen / Curves

-- Linien (Mauerkante rechts, links)
INSERT INTO po_polygons(gml_id,thema,layer,polygon,signaturnummer,modell)
SELECT
	gml_id,
	'Gebäude' AS thema,
	'ax_sonstigesbauwerkodersonstigeeinrichtung' AS layer,
	st_multi(polygon),
	2510 AS signaturnummer,
	modell
FROM (
	SELECT
		o.gml_id,
		alkis_bufferline(
			CASE
			WHEN bauwerksfunktion IN (1701, 1721) THEN st_reverse(alkis_safe_offsetcurve(wkb_geometry, -0.75, ''))  -- TODO: verify
			WHEN bauwerksfunktion IN (1702, 1722) THEN alkis_safe_offsetcurve(wkb_geometry, 0.75, '')		-- TODO: verify
			ELSE wkb_geometry
			END,
			0.5
		) AS polygon,
		advstandardmodell||sonstigesmodell AS modell
	FROM ks_sonstigesbauwerkodersonstigeeinrichtung o
	WHERE bauwerksfunktion IN (1701,1702,1703,1721,1722,1723)
	  AND geometrytype(wkb_geometry) IN ('LINESTRING','MULTILINESTRING')
	  AND endet IS NULL
	  AND 'HBDKOM' = ANY(sonstigesmodell)
) AS o;

-- Treppenunterkante / Zaun
INSERT INTO po_lines(gml_id,thema,layer,line,signaturnummer,modell)
SELECT
	gml_id,
	'Gebäude' AS thema,
	'ks_sonstigesbauwerkodersonstigeeinrichtung' AS layer,
	st_multi(line),
	signaturnummer,
	modell
FROM (
	SELECT
		o.gml_id,
		wkb_geometry AS line,
		CASE
		WHEN bauwerksfunktion=1630 THEN 2507
		WHEN bauwerksfunktion=1740 THEN 2002
		END AS signaturnummer,
		advstandardmodell||sonstigesmodell AS modell
	FROM ks_sonstigesbauwerkodersonstigeeinrichtung o
	WHERE geometrytype(wkb_geometry) IN ('LINESTRING','MULTILINESTRING')
	  AND endet IS NULL
	  AND 'HBDKOM' = ANY(sonstigesmodell)
) AS o
WHERE NOT signaturnummer IS NULL;

-- Zaun
INSERT INTO po_lines(gml_id,thema,layer,line,signaturnummer,modell)
SELECT
	gml_id,
	'Gebäude' AS thema,
	'ks_sonstigesbauwerkodersonstigeeinrichtung' AS layer,
	st_multi(
		st_collect(
			st_makeline(
				point,
				st_translate(
					point,
					0.3*sin(drehwinkel),
					0.3*cos(drehwinkel)
				)
			)
		)
	) AS line,
	2002 AS signaturnummer,
	modell
FROM (
	SELECT
		gml_id,
		st_lineinterpolatepoint(line,o.offset/len) AS point,
		st_azimuth(
			st_lineinterpolatepoint(line, o.offset/len*0.999),
			st_lineinterpolatepoint(line, o.offset/len)
		)+0.5*pi()*CASE WHEN o.offset%2=0 THEN 1 ELSE -1 END AS drehwinkel,
		modell
	FROM (
		SELECT
			o.gml_id,
			line,
			st_length(line) AS len,
			generate_series(1,trunc(st_length(line))::int) AS offset,
			modell
		FROM (
			SELECT
				gml_id,
			        (st_dump(st_multi(wkb_geometry))).geom AS line,
			        advstandardmodell||sonstigesmodell AS modell
			FROM ks_sonstigesbauwerkodersonstigeeinrichtung
			WHERE geometrytype(wkb_geometry) IN ('LINESTRING','MULTILINESTRING')
			  AND endet IS NULL
			  AND bauwerksfunktion=1740
			  AND 'HBDKOM' = ANY(sonstigesmodell)
		) AS o
	) AS o
) AS o
GROUP BY gml_id,modell;

-- Symbole
INSERT INTO po_points(gml_id,thema,layer,point,drehwinkel,signaturnummer,modell)
SELECT
	gml_id,
	'Gebäude' AS thema,
	'ks_sonstigesbauwerkodersonstigeeinrichtung' AS layer,
	st_multi(point),
	drehwinkel,
	signaturnummer,
	modell
FROM (
	SELECT
		o.gml_id,
		coalesce(
			p.wkb_geometry,
			CASE
			WHEN geometrytype(o.wkb_geometry) IN ('POINT','MULTIPOINT')     THEN o.wkb_geometry
			WHEN geometrytype(o.wkb_geometry) IN ('POLYGON','MULTIPOLYGON') THEN st_centroid(o.wkb_geometry)
			END
		) AS point,
		coalesce(p.drehwinkel,0) AS drehwinkel,
		coalesce(
			d.signaturnummer,
			p.signaturnummer,
			CASE
			WHEN bauwerksfunktion=1780 AND geometrytype(o.wkb_geometry) IN ('POINT','MULTIPOINT') THEN '3529'
			WHEN bauwerksfunktion=1781                                                            THEN '3537'
			WHEN bauwerksfunktion=1782                                                            THEN '3539'
			END
		) AS signaturnummer,
		coalesce(
			p.advstandardmodell||p.sonstigesmodell,
			d.advstandardmodell||d.sonstigesmodell,
			o.advstandardmodell||o.sonstigesmodell
		) AS modell
	FROM ks_sonstigesbauwerkodersonstigeeinrichtung o
	LEFT OUTER JOIN ap_ppo_unnested p ON o.gml_id = p.dientzurdarstellungvon_unnested AND p.art='BWF' AND p.endet IS NULL
	LEFT OUTER JOIN ap_darstellung_unnested d ON o.gml_id = d.dientzurdarstellungvon_unnested AND d.art='BWF' AND d.endet IS NULL
	WHERE o.endet IS NULL
	  AND 'HBDKOM' = ANY(o.sonstigesmodell||p.sonstigesmodell||d.sonstigesmodell)
) AS o
WHERE NOT signaturnummer IS NULL;

-- Texte
INSERT INTO po_labels(gml_id,thema,layer,point,text,signaturnummer,drehwinkel,horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,modell)
SELECT
	gml_id,
	'Gebäude' AS thema,
	'ks_sonstigesbauwerkodersonstigeeinrichtung' AS layer,
	point,
	text,
	signaturnummer,
	drehwinkel,horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,modell
FROM (
	SELECT
		o.gml_id,
		coalesce(
			t.wkb_geometry,
			CASE
			WHEN geometrytype(o.wkb_geometry) IN ('POINT','MULTIPOINT')     THEN st_translate(o.wkb_geometry, 0.5, 0)
			WHEN geometrytype(o.wkb_geometry) IN ('POLYGON','MULTIPOLYGON') THEN st_centroid(o.wkb_geometry)
			END
		) AS point,
		CASE
		WHEN bauwerksfunktion IN (1780,1781) THEN
			coalesce(
				t.schriftinhalt,
				'Br'
			)
		END AS text,
		coalesce(
			d.signaturnummer,
			t.signaturnummer,
			'4073'
		) AS signaturnummer,
		drehwinkel,horizontaleausrichtung,vertikaleausrichtung,skalierung,fontsperrung,
		coalesce(
			t.advstandardmodell||t.sonstigesmodell,
			d.advstandardmodell||d.sonstigesmodell,
			o.advstandardmodell||o.sonstigesmodell
		) AS modell
	FROM ks_sonstigesbauwerkodersonstigeeinrichtung o
	LEFT OUTER JOIN ap_pto_unnested t ON o.gml_id = t.dientzurdarstellungvon_unnested AND t.art='BWF' AND t.endet IS NULL
	LEFT OUTER JOIN ap_darstellung_unnested d ON o.gml_id = d.dientzurdarstellungvon_unnested AND d.art='BWF' AND d.endet IS NULL
	WHERE o.endet IS NULL AND geometrytype(o.wkb_geometry) IN ('POINT', 'MULTIPOINT', 'POLYGON', 'MULTIPOLYGON')
) AS n WHERE NOT text IS NULL AND NOT signaturnummer IS NULL;
