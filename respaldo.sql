--
-- PostgreSQL database dump
--

\restrict HNSSc9kAOfTWUEmbdDfQJ44m2fWc4yYTmECuKRj3dkPGGK4oN3tfFVAXxzWdClj

-- Dumped from database version 18.2
-- Dumped by pg_dump version 18.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: fn_aprendices_pendientes(character varying, integer, integer, integer, character varying, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_aprendices_pendientes(p_documento character varying DEFAULT NULL::character varying, p_id_ficha integer DEFAULT NULL::integer, p_id_programa integer DEFAULT NULL::integer, p_id_estado integer DEFAULT NULL::integer, p_nombre_aprendiz character varying DEFAULT NULL::character varying, p_min_pendientes integer DEFAULT NULL::integer) RETURNS TABLE(documento character varying, tipo_documento character varying, aprendiz text, email character varying, telefono character varying, codigo_ficha character varying, programa character varying, estado_matricula character varying, juicios_pendientes bigint, sin_evaluar bigint, total_pendientes bigint)
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RETURN QUERY
      SELECT
        a.documento,
        a.tipo_documento,
        CONCAT(a.nombres, ' ', a.apellidos) AS aprendiz,
        a.email,
        a.telefono,
        f.codigo_ficha,
        p.denominacion AS programa,
        ea.descripcion AS estado_matricula,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'PE' THEN je.id_juicio END) AS juicios_pendientes,
        COUNT(DISTINCT CASE WHEN je.id_juicio IS NULL THEN ra.id_resultado END) AS sin_evaluar,
        (COUNT(DISTINCT CASE WHEN tj.codigo = 'PE' THEN je.id_juicio END) +
         COUNT(DISTINCT CASE WHEN je.id_juicio IS NULL THEN ra.id_resultado END)) AS total_pendientes
      FROM aprendiz a
      JOIN matricula m ON a.documento = m.id_aprendiz
      JOIN estado_aprendiz ea ON m.id_estado = ea.id_estado
      JOIN ficha f ON m.id_ficha = f.id_ficha
      JOIN programa p ON f.id_programa = p.id
      JOIN competencia c ON p.id = c.id_programa
      JOIN resultado_aprendizaje ra ON c.id_competencia = ra.id_competencia
      LEFT JOIN juicios_evaluativos je ON m.id_matricula = je.id_matricula
        AND ra.id_resultado = je.id_resultado
      LEFT JOIN tipo_juicio tj ON je.id_tipo = tj.id
      WHERE (tj.codigo = 'PE' OR je.id_juicio IS NULL)
        AND (p_documento IS NULL OR a.documento = p_documento)
        AND (p_id_ficha IS NULL OR f.id_ficha = p_id_ficha)
        AND (p_id_programa IS NULL OR p.id = p_id_programa)
        AND (p_id_estado IS NULL OR m.id_estado = p_id_estado)
        AND (p_nombre_aprendiz IS NULL OR CONCAT(a.nombres, ' ', a.apellidos) ILIKE '%' || p_nombre_aprendiz || '%')
      GROUP BY a.documento, a.tipo_documento, a.nombres, a.apellidos, a.email, a.telefono,
               f.codigo_ficha, p.denominacion, ea.descripcion
      HAVING (p_min_pendientes IS NULL OR 
              (COUNT(DISTINCT CASE WHEN tj.codigo = 'PE' THEN je.id_juicio END) +
               COUNT(DISTINCT CASE WHEN je.id_juicio IS NULL THEN ra.id_resultado END)) >= p_min_pendientes)
      ORDER BY total_pendientes DESC, a.apellidos;
    END;
    $$;


ALTER FUNCTION public.fn_aprendices_pendientes(p_documento character varying, p_id_ficha integer, p_id_programa integer, p_id_estado integer, p_nombre_aprendiz character varying, p_min_pendientes integer) OWNER TO postgres;

--
-- Name: fn_aprendices_por_estado(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_aprendices_por_estado(p_id_estado integer DEFAULT NULL::integer, p_codigo_estado character varying DEFAULT NULL::character varying) RETURNS TABLE(id_estado integer, codigo character varying, estado character varying, total_aprendices bigint, porcentaje numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ea.id_estado,
        ea.codigo,
        ea.descripcion AS estado,
        COUNT(DISTINCT m.id_aprendiz) AS total_aprendices,
        ROUND(COUNT(DISTINCT m.id_aprendiz) * 100.0 / 
            NULLIF((SELECT COUNT(DISTINCT id_aprendiz) FROM matricula), 0), 2) AS porcentaje
    FROM estado_aprendiz ea
    LEFT JOIN matricula m ON ea.id_estado = m.id_estado
    WHERE (p_id_estado IS NULL OR ea.id_estado = p_id_estado)
      AND (p_codigo_estado IS NULL OR ea.codigo = p_codigo_estado)
    GROUP BY ea.id_estado, ea.codigo, ea.descripcion
    ORDER BY total_aprendices DESC;
END;
$$;


ALTER FUNCTION public.fn_aprendices_por_estado(p_id_estado integer, p_codigo_estado character varying) OWNER TO postgres;

--
-- Name: fn_avance_aprendiz(character varying, integer, integer, numeric, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_avance_aprendiz(p_documento character varying DEFAULT NULL::character varying, p_id_ficha integer DEFAULT NULL::integer, p_id_programa integer DEFAULT NULL::integer, p_min_avance numeric DEFAULT NULL::numeric, p_max_avance numeric DEFAULT NULL::numeric) RETURNS TABLE(documento character varying, aprendiz text, codigo_ficha character varying, programa character varying, total_resultados bigint, resultados_aprobados bigint, resultados_pendientes bigint, resultados_no_aprobados bigint, porcentaje_avance numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.documento,
        CONCAT(a.nombres, ' ', a.apellidos) AS aprendiz,
        f.codigo_ficha,
        p.denominacion AS programa,
        COUNT(DISTINCT ra_total.id_resultado) AS total_resultados,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN ra_eval.id_resultado END) AS resultados_aprobados,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'PE' THEN ra_eval.id_resultado END) AS resultados_pendientes,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'NA' THEN ra_eval.id_resultado END) AS resultados_no_aprobados,
        ROUND(
            COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN ra_eval.id_resultado END) * 100.0 / 
            NULLIF(COUNT(DISTINCT ra_total.id_resultado), 0), 2
        ) AS porcentaje_avance
    FROM aprendiz a
    JOIN matricula m ON a.documento = m.id_aprendiz
    JOIN ficha f ON m.id_ficha = f.id_ficha
    JOIN programa p ON f.id_programa = p.id
    JOIN competencia c ON p.id = c.id_programa
    JOIN resultado_aprendizaje ra_total ON c.id_competencia = ra_total.id_competencia
    LEFT JOIN juicios_evaluativos je ON m.id_matricula = je.id_matricula
    LEFT JOIN resultado_aprendizaje ra_eval ON je.id_resultado = ra_eval.id_resultado
    LEFT JOIN tipo_juicio tj ON je.id_tipo = tj.id
    WHERE (p_documento IS NULL OR a.documento = p_documento)
      AND (p_id_ficha IS NULL OR f.id_ficha = p_id_ficha)
      AND (p_id_programa IS NULL OR p.id = p_id_programa)
    GROUP BY a.documento, a.nombres, a.apellidos, f.codigo_ficha, p.denominacion
    HAVING (p_min_avance IS NULL OR 
            ROUND(COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN ra_eval.id_resultado END) * 100.0 / 
            NULLIF(COUNT(DISTINCT ra_total.id_resultado), 0), 2) >= p_min_avance)
       AND (p_max_avance IS NULL OR 
            ROUND(COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN ra_eval.id_resultado END) * 100.0 / 
            NULLIF(COUNT(DISTINCT ra_total.id_resultado), 0), 2) <= p_max_avance)
    ORDER BY porcentaje_avance DESC;
END;
$$;


ALTER FUNCTION public.fn_avance_aprendiz(p_documento character varying, p_id_ficha integer, p_id_programa integer, p_min_avance numeric, p_max_avance numeric) OWNER TO postgres;

--
-- Name: fn_busqueda_maestra(integer, integer, character varying, date, date, character varying, character varying, character varying, character varying, integer, character varying, integer, character varying, character varying, integer, character varying, integer, character varying, integer, character varying, integer, character varying, character varying, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_busqueda_maestra(p_id_juicio integer DEFAULT NULL::integer, p_id_tipo_juicio integer DEFAULT NULL::integer, p_codigo_juicio character varying DEFAULT NULL::character varying, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_documento_aprendiz character varying DEFAULT NULL::character varying, p_tipo_documento character varying DEFAULT NULL::character varying, p_nombre_aprendiz character varying DEFAULT NULL::character varying, p_email_aprendiz character varying DEFAULT NULL::character varying, p_id_ficha integer DEFAULT NULL::integer, p_codigo_ficha character varying DEFAULT NULL::character varying, p_id_programa integer DEFAULT NULL::integer, p_codigo_programa character varying DEFAULT NULL::character varying, p_nivel_formacion character varying DEFAULT NULL::character varying, p_id_estado integer DEFAULT NULL::integer, p_estado_aprendiz character varying DEFAULT NULL::character varying, p_id_competencia integer DEFAULT NULL::integer, p_codigo_competencia character varying DEFAULT NULL::character varying, p_id_resultado integer DEFAULT NULL::integer, p_codigo_resultado character varying DEFAULT NULL::character varying, p_id_funcionario integer DEFAULT NULL::integer, p_nombre_funcionario character varying DEFAULT NULL::character varying, p_cargo_funcionario character varying DEFAULT NULL::character varying, p_orden character varying DEFAULT 'fecha_desc'::character varying, p_limite integer DEFAULT 100, p_offset integer DEFAULT 0) RETURNS TABLE(id_juicio integer, fecha_hora timestamp without time zone, juicio character varying, cod_juicio character varying, doc_aprendiz character varying, aprendiz text, email character varying, codigo_ficha character varying, codigo_programa character varying, programa character varying, estado_aprendiz character varying, codigo_competencia character varying, nombre_competencia character varying, codigo_resultado character varying, resultado text, funcionario text, cargo_funcionario character varying, observaciones text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        je.id_juicio,
        je.fecha AS fecha_hora,
        tj.nombre AS juicio,
        tj.codigo AS cod_juicio,
        a.documento AS doc_aprendiz,
        CONCAT(a.nombres, ' ', a.apellidos) AS aprendiz,
        a.email,
        f.codigo_ficha,
        p.codigo_programa,
        p.denominacion AS programa,
        ea.descripcion AS estado_aprendiz,
        c.codigo_competencia,
        c.nombre_competencia,
        ra.codigo_resultado,
        ra.descripcion AS resultado,
        CONCAT(func.nombres, ' ', func.apellidos) AS funcionario,
        func.cargo AS cargo_funcionario,
        je.observaciones
    FROM juicios_evaluativos je
    JOIN tipo_juicio tj ON je.id_tipo = tj.id
    JOIN matricula m ON je.id_matricula = m.id_matricula
    JOIN aprendiz a ON m.id_aprendiz = a.documento
    JOIN estado_aprendiz ea ON m.id_estado = ea.id_estado
    JOIN ficha f ON m.id_ficha = f.id_ficha
    JOIN programa p ON f.id_programa = p.id
    JOIN resultado_aprendizaje ra ON je.id_resultado = ra.id_resultado
    JOIN competencia c ON ra.id_competencia = c.id_competencia
    JOIN funcionario func ON je.id_funcionario = func.id_funcionario
    WHERE (p_id_juicio IS NULL OR je.id_juicio = p_id_juicio)
      AND (p_id_tipo_juicio IS NULL OR je.id_tipo = p_id_tipo_juicio)
      AND (p_codigo_juicio IS NULL OR tj.codigo = p_codigo_juicio)
      AND (p_fecha_desde IS NULL OR DATE(je.fecha) >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR DATE(je.fecha) <= p_fecha_hasta)
      AND (p_documento_aprendiz IS NULL OR a.documento = p_documento_aprendiz)
      AND (p_tipo_documento IS NULL OR a.tipo_documento = p_tipo_documento)
      AND (p_nombre_aprendiz IS NULL OR CONCAT(a.nombres, ' ', a.apellidos) ILIKE '%' || p_nombre_aprendiz || '%')
      AND (p_email_aprendiz IS NULL OR a.email = p_email_aprendiz)
      AND (p_id_ficha IS NULL OR f.id_ficha = p_id_ficha)
      AND (p_codigo_ficha IS NULL OR f.codigo_ficha = p_codigo_ficha)
      AND (p_id_programa IS NULL OR p.id = p_id_programa)
      AND (p_codigo_programa IS NULL OR p.codigo_programa = p_codigo_programa)
      AND (p_nivel_formacion IS NULL OR p.nivel_formacion = p_nivel_formacion)
      AND (p_id_estado IS NULL OR m.id_estado = p_id_estado)
      AND (p_estado_aprendiz IS NULL OR ea.descripcion = p_estado_aprendiz)
      AND (p_id_competencia IS NULL OR c.id_competencia = p_id_competencia)
      AND (p_codigo_competencia IS NULL OR c.codigo_competencia = p_codigo_competencia)
      AND (p_id_resultado IS NULL OR ra.id_resultado = p_id_resultado)
      AND (p_codigo_resultado IS NULL OR ra.codigo_resultado = p_codigo_resultado)
      AND (p_id_funcionario IS NULL OR func.id_funcionario = p_id_funcionario)
      AND (p_nombre_funcionario IS NULL OR CONCAT(func.nombres, ' ', func.apellidos) ILIKE '%' || p_nombre_funcionario || '%')
      AND (p_cargo_funcionario IS NULL OR func.cargo = p_cargo_funcionario)
    ORDER BY 
        CASE WHEN p_orden = 'fecha_asc' THEN je.fecha END ASC,
        CASE WHEN p_orden = 'fecha_desc' THEN je.fecha END DESC,
        CASE WHEN p_orden = 'aprendiz' THEN a.apellidos END ASC,
        CASE WHEN p_orden IS NULL OR p_orden = '' THEN je.fecha END DESC
    LIMIT p_limite OFFSET p_offset;
END;
$$;


ALTER FUNCTION public.fn_busqueda_maestra(p_id_juicio integer, p_id_tipo_juicio integer, p_codigo_juicio character varying, p_fecha_desde date, p_fecha_hasta date, p_documento_aprendiz character varying, p_tipo_documento character varying, p_nombre_aprendiz character varying, p_email_aprendiz character varying, p_id_ficha integer, p_codigo_ficha character varying, p_id_programa integer, p_codigo_programa character varying, p_nivel_formacion character varying, p_id_estado integer, p_estado_aprendiz character varying, p_id_competencia integer, p_codigo_competencia character varying, p_id_resultado integer, p_codigo_resultado character varying, p_id_funcionario integer, p_nombre_funcionario character varying, p_cargo_funcionario character varying, p_orden character varying, p_limite integer, p_offset integer) OWNER TO postgres;

--
-- Name: fn_competencias_aprobacion(integer, integer, numeric); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_competencias_aprobacion(p_id_programa integer DEFAULT NULL::integer, p_id_competencia integer DEFAULT NULL::integer, p_min_aprobacion numeric DEFAULT NULL::numeric) RETURNS TABLE(programa character varying, id_competencia integer, codigo_competencia character varying, nombre_competencia character varying, total_evaluaciones bigint, juicios_aprobados bigint, juicios_no_aprobados bigint, juicios_pendientes bigint, porcentaje_aprobacion numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.denominacion AS programa,
        c.id_competencia,
        c.codigo_competencia,
        c.nombre_competencia,
        COUNT(DISTINCT je.id_juicio) AS total_evaluaciones,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN je.id_juicio END) AS juicios_aprobados,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'NA' THEN je.id_juicio END) AS juicios_no_aprobados,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'PE' THEN je.id_juicio END) AS juicios_pendientes,
        ROUND(
            COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN je.id_juicio END) * 100.0 / 
            NULLIF(COUNT(DISTINCT je.id_juicio), 0), 2
        ) AS porcentaje_aprobacion
    FROM competencia c
    JOIN programa p ON c.id_programa = p.id
    LEFT JOIN resultado_aprendizaje ra ON c.id_competencia = ra.id_competencia
    LEFT JOIN juicios_evaluativos je ON ra.id_resultado = je.id_resultado
    LEFT JOIN tipo_juicio tj ON je.id_tipo = tj.id
    WHERE (p_id_programa IS NULL OR p.id = p_id_programa)
      AND (p_id_competencia IS NULL OR c.id_competencia = p_id_competencia)
    GROUP BY p.denominacion, c.id_competencia, c.codigo_competencia, c.nombre_competencia
    HAVING (p_min_aprobacion IS NULL OR 
            ROUND(COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN je.id_juicio END) * 100.0 / 
            NULLIF(COUNT(DISTINCT je.id_juicio), 0), 2) >= p_min_aprobacion)
    ORDER BY porcentaje_aprobacion DESC, total_evaluaciones DESC;
END;
$$;


ALTER FUNCTION public.fn_competencias_aprobacion(p_id_programa integer, p_id_competencia integer, p_min_aprobacion numeric) OWNER TO postgres;

--
-- Name: fn_dashboard_aprendices_formacion(integer, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_dashboard_aprendices_formacion(p_id_programa integer DEFAULT NULL::integer, p_nivel_formacion character varying DEFAULT NULL::character varying, p_estado_programa character varying DEFAULT NULL::character varying) RETURNS TABLE(id_programa integer, codigo_programa character varying, denominacion character varying, nivel_formacion character varying, total_aprendices bigint, total_fichas_activas bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS id_programa,
        p.codigo_programa,
        p.denominacion,
        p.nivel_formacion,
        COUNT(DISTINCT m.id_aprendiz) AS total_aprendices,
        COUNT(DISTINCT f.id_ficha) AS total_fichas_activas
    FROM programa p
    LEFT JOIN ficha f ON p.id = f.id_programa AND f.estado_ficha = 'Activa'
    LEFT JOIN matricula m ON f.id_ficha = m.id_ficha
    WHERE (p_id_programa IS NULL OR p.id = p_id_programa)
      AND (p_nivel_formacion IS NULL OR p.nivel_formacion = p_nivel_formacion)
      AND (p_estado_programa IS NULL OR p.estado = p_estado_programa)
    GROUP BY p.id, p.codigo_programa, p.denominacion, p.nivel_formacion
    ORDER BY total_aprendices DESC;
END;
$$;


ALTER FUNCTION public.fn_dashboard_aprendices_formacion(p_id_programa integer, p_nivel_formacion character varying, p_estado_programa character varying) OWNER TO postgres;

--
-- Name: fn_dashboard_aprobacion_programa(integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_dashboard_aprobacion_programa(p_id_programa integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date) RETURNS TABLE(id_programa integer, codigo_programa character varying, denominacion character varying, total_juicios bigint, aprobados bigint, no_aprobados bigint, pendientes bigint, porcentaje_aprobacion numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id AS id_programa,
        p.codigo_programa,
        p.denominacion,
        COUNT(DISTINCT je.id_juicio) AS total_juicios,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN je.id_juicio END) AS aprobados,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'NA' THEN je.id_juicio END) AS no_aprobados,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'PE' THEN je.id_juicio END) AS pendientes,
        ROUND(
            COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN je.id_juicio END) * 100.0 / 
            NULLIF(COUNT(DISTINCT je.id_juicio), 0), 2
        ) AS porcentaje_aprobacion
    FROM programa p
    LEFT JOIN ficha f ON p.id = f.id_programa
    LEFT JOIN matricula m ON f.id_ficha = m.id_ficha
    LEFT JOIN juicios_evaluativos je ON m.id_matricula = je.id_matricula
    LEFT JOIN tipo_juicio tj ON je.id_tipo = tj.id
    WHERE (p_id_programa IS NULL OR p.id = p_id_programa)
      AND (p_fecha_desde IS NULL OR DATE(je.fecha) >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR DATE(je.fecha) <= p_fecha_hasta)
    GROUP BY p.id, p.codigo_programa, p.denominacion
    ORDER BY porcentaje_aprobacion DESC;
END;
$$;


ALTER FUNCTION public.fn_dashboard_aprobacion_programa(p_id_programa integer, p_fecha_desde date, p_fecha_hasta date) OWNER TO postgres;

--
-- Name: fn_dashboard_aprobados_vs_pendientes(integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_dashboard_aprobados_vs_pendientes(p_id_programa integer DEFAULT NULL::integer, p_id_ficha integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date) RETURNS TABLE(programa character varying, codigo_ficha character varying, aprobados bigint, pendientes bigint, no_aprobados bigint, total_juicios bigint, tasa_aprobacion numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.denominacion AS programa,
        f.codigo_ficha,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN je.id_juicio END) AS aprobados,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'PE' THEN je.id_juicio END) AS pendientes,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'NA' THEN je.id_juicio END) AS no_aprobados,
        COUNT(DISTINCT je.id_juicio) AS total_juicios,
        ROUND(
            COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN je.id_juicio END) * 100.0 / 
            NULLIF(COUNT(DISTINCT je.id_juicio), 0), 2
        ) AS tasa_aprobacion
    FROM programa p
    LEFT JOIN ficha f ON p.id = f.id_programa
    LEFT JOIN matricula m ON f.id_ficha = m.id_ficha
    LEFT JOIN juicios_evaluativos je ON m.id_matricula = je.id_matricula
    LEFT JOIN tipo_juicio tj ON je.id_tipo = tj.id
    WHERE (p_id_programa IS NULL OR p.id = p_id_programa)
      AND (p_id_ficha IS NULL OR f.id_ficha = p_id_ficha)
      AND (p_fecha_desde IS NULL OR DATE(je.fecha) >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR DATE(je.fecha) <= p_fecha_hasta)
    GROUP BY p.denominacion, f.codigo_ficha
    ORDER BY tasa_aprobacion DESC;
END;
$$;


ALTER FUNCTION public.fn_dashboard_aprobados_vs_pendientes(p_id_programa integer, p_id_ficha integer, p_fecha_desde date, p_fecha_hasta date) OWNER TO postgres;

--
-- Name: fn_dashboard_avance_competencia(character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_dashboard_avance_competencia(p_documento character varying DEFAULT NULL::character varying, p_id_ficha integer DEFAULT NULL::integer, p_id_competencia integer DEFAULT NULL::integer) RETURNS TABLE(documento character varying, aprendiz text, codigo_ficha character varying, codigo_competencia character varying, nombre_competencia character varying, total_resultados_competencia bigint, aprobados bigint, porcentaje_avance_competencia numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.documento,
        CONCAT(a.nombres, ' ', a.apellidos) AS aprendiz,
        f.codigo_ficha,
        c.codigo_competencia,
        c.nombre_competencia,
        COUNT(DISTINCT ra_total.id_resultado) AS total_resultados_competencia,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN ra_eval.id_resultado END) AS aprobados,
        ROUND(
            COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN ra_eval.id_resultado END) * 100.0 / 
            NULLIF(COUNT(DISTINCT ra_total.id_resultado), 0), 2
        ) AS porcentaje_avance_competencia
    FROM aprendiz a
    JOIN matricula m ON a.documento = m.id_aprendiz
    JOIN ficha f ON m.id_ficha = f.id_ficha
    JOIN programa p ON f.id_programa = p.id
    JOIN competencia c ON p.id = c.id_programa
    JOIN resultado_aprendizaje ra_total ON c.id_competencia = ra_total.id_competencia
    LEFT JOIN juicios_evaluativos je ON m.id_matricula = je.id_matricula
    LEFT JOIN resultado_aprendizaje ra_eval ON je.id_resultado = ra_eval.id_resultado
    LEFT JOIN tipo_juicio tj ON je.id_tipo = tj.id
    WHERE (p_documento IS NULL OR a.documento = p_documento)
      AND (p_id_ficha IS NULL OR f.id_ficha = p_id_ficha)
      AND (p_id_competencia IS NULL OR c.id_competencia = p_id_competencia)
    GROUP BY a.documento, a.nombres, a.apellidos, f.codigo_ficha, 
             c.id_competencia, c.codigo_competencia, c.nombre_competencia
    ORDER BY a.apellidos, c.codigo_competencia;
END;
$$;


ALTER FUNCTION public.fn_dashboard_avance_competencia(p_documento character varying, p_id_ficha integer, p_id_competencia integer) OWNER TO postgres;

--
-- Name: fn_juicios_por_fecha(date, date, date, time without time zone, time without time zone, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_juicios_por_fecha(p_fecha_exacta date DEFAULT NULL::date, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date, p_hora_desde time without time zone DEFAULT NULL::time without time zone, p_hora_hasta time without time zone DEFAULT NULL::time without time zone, "p_año" integer DEFAULT NULL::integer, p_mes integer DEFAULT NULL::integer, p_semana integer DEFAULT NULL::integer) RETURNS TABLE(id_juicio integer, fecha_hora_registro timestamp without time zone, solo_fecha date, solo_hora time without time zone, "año" integer, mes integer, semana integer, tipo_juicio character varying, doc_aprendiz character varying, aprendiz text, codigo_ficha character varying, codigo_resultado character varying, resultado text, registrado_por text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        je.id_juicio,
        je.fecha AS fecha_hora_registro,
        DATE(je.fecha) AS solo_fecha,
        CAST(je.fecha AS TIME) AS solo_hora,
        EXTRACT(YEAR FROM je.fecha)::INTEGER AS año,
        EXTRACT(MONTH FROM je.fecha)::INTEGER AS mes,
        EXTRACT(WEEK FROM je.fecha)::INTEGER AS semana,
        tj.nombre AS tipo_juicio,
        a.documento AS doc_aprendiz,
        CONCAT(a.nombres, ' ', a.apellidos) AS aprendiz,
        f.codigo_ficha,
        ra.codigo_resultado,
        ra.descripcion AS resultado,
        CONCAT(func.nombres, ' ', func.apellidos) AS registrado_por
    FROM juicios_evaluativos je
    JOIN tipo_juicio tj ON je.id_tipo = tj.id
    JOIN matricula m ON je.id_matricula = m.id_matricula
    JOIN aprendiz a ON m.id_aprendiz = a.documento
    JOIN ficha f ON m.id_ficha = f.id_ficha
    JOIN resultado_aprendizaje ra ON je.id_resultado = ra.id_resultado
    JOIN funcionario func ON je.id_funcionario = func.id_funcionario
    WHERE (p_fecha_exacta IS NULL OR DATE(je.fecha) = p_fecha_exacta)
      AND (p_fecha_desde IS NULL OR DATE(je.fecha) >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR DATE(je.fecha) <= p_fecha_hasta)
      AND (p_hora_desde IS NULL OR CAST(je.fecha AS TIME) >= p_hora_desde)
      AND (p_hora_hasta IS NULL OR CAST(je.fecha AS TIME) <= p_hora_hasta)
      AND (p_año IS NULL OR EXTRACT(YEAR FROM je.fecha) = p_año)
      AND (p_mes IS NULL OR EXTRACT(MONTH FROM je.fecha) = p_mes)
      AND (p_semana IS NULL OR EXTRACT(WEEK FROM je.fecha) = p_semana)
    ORDER BY je.fecha DESC;
END;
$$;


ALTER FUNCTION public.fn_juicios_por_fecha(p_fecha_exacta date, p_fecha_desde date, p_fecha_hasta date, p_hora_desde time without time zone, p_hora_hasta time without time zone, "p_año" integer, p_mes integer, p_semana integer) OWNER TO postgres;

--
-- Name: fn_juicios_por_funcionario(integer, character varying, character varying, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_juicios_por_funcionario(p_id_funcionario integer DEFAULT NULL::integer, p_nombre_funcionario character varying DEFAULT NULL::character varying, p_cargo character varying DEFAULT NULL::character varying, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date) RETURNS TABLE(id_juicio integer, fecha_hora timestamp without time zone, tipo_juicio character varying, codigo_juicio character varying, doc_aprendiz character varying, aprendiz text, codigo_ficha character varying, codigo_competencia character varying, nombre_competencia character varying, codigo_resultado character varying, resultado text, id_funcionario integer, funcionario text, cargo_funcionario character varying, observaciones text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        je.id_juicio,
        je.fecha AS fecha_hora,
        tj.nombre AS tipo_juicio,
        tj.codigo AS codigo_juicio,
        a.documento AS doc_aprendiz,
        CONCAT(a.nombres, ' ', a.apellidos) AS aprendiz,
        f.codigo_ficha,
        c.codigo_competencia,
        c.nombre_competencia,
        ra.codigo_resultado,
        ra.descripcion AS resultado,
        func.id_funcionario,
        CONCAT(func.nombres, ' ', func.apellidos) AS funcionario,
        func.cargo AS cargo_funcionario,
        je.observaciones
    FROM juicios_evaluativos je
    JOIN tipo_juicio tj ON je.id_tipo = tj.id
    JOIN matricula m ON je.id_matricula = m.id_matricula
    JOIN aprendiz a ON m.id_aprendiz = a.documento
    JOIN ficha f ON m.id_ficha = f.id_ficha
    JOIN resultado_aprendizaje ra ON je.id_resultado = ra.id_resultado
    JOIN competencia c ON ra.id_competencia = c.id_competencia
    JOIN funcionario func ON je.id_funcionario = func.id_funcionario
    WHERE (p_id_funcionario IS NULL OR func.id_funcionario = p_id_funcionario)
      AND (p_nombre_funcionario IS NULL OR CONCAT(func.nombres, ' ', func.apellidos) ILIKE '%' || p_nombre_funcionario || '%')
      AND (p_cargo IS NULL OR func.cargo = p_cargo)
      AND (p_fecha_desde IS NULL OR DATE(je.fecha) >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR DATE(je.fecha) <= p_fecha_hasta)
    ORDER BY je.fecha DESC;
END;
$$;


ALTER FUNCTION public.fn_juicios_por_funcionario(p_id_funcionario integer, p_nombre_funcionario character varying, p_cargo character varying, p_fecha_desde date, p_fecha_hasta date) OWNER TO postgres;

--
-- Name: fn_resultados_aprobados(integer, integer, integer, date, date); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_resultados_aprobados(p_id_programa integer DEFAULT NULL::integer, p_id_competencia integer DEFAULT NULL::integer, p_id_resultado integer DEFAULT NULL::integer, p_fecha_desde date DEFAULT NULL::date, p_fecha_hasta date DEFAULT NULL::date) RETURNS TABLE(programa character varying, codigo_competencia character varying, nombre_competencia character varying, codigo_resultado character varying, resultado text, total_juicios_aprobados bigint, total_aprendices_aprobados bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.denominacion AS programa,
        c.codigo_competencia,
        c.nombre_competencia,
        ra.codigo_resultado,
        ra.descripcion AS resultado,
        COUNT(DISTINCT je.id_juicio) AS total_juicios_aprobados,
        COUNT(DISTINCT je.id_matricula) AS total_aprendices_aprobados
    FROM resultado_aprendizaje ra
    JOIN competencia c ON ra.id_competencia = c.id_competencia
    JOIN programa p ON c.id_programa = p.id
    JOIN juicios_evaluativos je ON ra.id_resultado = je.id_resultado
    JOIN tipo_juicio tj ON je.id_tipo = tj.id
    WHERE tj.codigo = 'AP'
      AND (p_id_programa IS NULL OR p.id = p_id_programa)
      AND (p_id_competencia IS NULL OR c.id_competencia = p_id_competencia)
      AND (p_id_resultado IS NULL OR ra.id_resultado = p_id_resultado)
      AND (p_fecha_desde IS NULL OR DATE(je.fecha) >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR DATE(je.fecha) <= p_fecha_hasta)
    GROUP BY p.denominacion, c.codigo_competencia, c.nombre_competencia, ra.codigo_resultado, ra.descripcion;
END;
$$;


ALTER FUNCTION public.fn_resultados_aprobados(p_id_programa integer, p_id_competencia integer, p_id_resultado integer, p_fecha_desde date, p_fecha_hasta date) OWNER TO postgres;

--
-- Name: fn_resultados_pendientes(character varying, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_resultados_pendientes(p_documento character varying DEFAULT NULL::character varying, p_id_ficha integer DEFAULT NULL::integer, p_id_programa integer DEFAULT NULL::integer, p_id_competencia integer DEFAULT NULL::integer) RETURNS TABLE(documento character varying, aprendiz text, codigo_ficha character varying, codigo_competencia character varying, nombre_competencia character varying, codigo_resultado character varying, resultado_pendiente text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.documento,
        CONCAT(a.nombres, ' ', a.apellidos) AS aprendiz,
        f.codigo_ficha,
        c.codigo_competencia,
        c.nombre_competencia,
        ra.codigo_resultado,
        ra.descripcion AS resultado_pendiente
    FROM aprendiz a
    JOIN matricula m ON a.documento = m.id_aprendiz
    JOIN ficha f ON m.id_ficha = f.id_ficha
    JOIN programa p ON f.id_programa = p.id
    JOIN competencia c ON p.id = c.id_programa
    JOIN resultado_aprendizaje ra ON c.id_competencia = ra.id_competencia
    LEFT JOIN juicios_evaluativos je ON m.id_matricula = je.id_matricula 
        AND ra.id_resultado = je.id_resultado
    WHERE je.id_juicio IS NULL
      AND (p_documento IS NULL OR a.documento = p_documento)
      AND (p_id_ficha IS NULL OR f.id_ficha = p_id_ficha)
      AND (p_id_programa IS NULL OR p.id = p_id_programa)
      AND (p_id_competencia IS NULL OR c.id_competencia = p_id_competencia)
    ORDER BY a.documento, c.codigo_competencia, ra.codigo_resultado;
END;
$$;


ALTER FUNCTION public.fn_resultados_pendientes(p_documento character varying, p_id_ficha integer, p_id_programa integer, p_id_competencia integer) OWNER TO postgres;

--
-- Name: fn_resultados_por_aprendiz(character varying, character varying, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_resultados_por_aprendiz(p_documento character varying DEFAULT NULL::character varying, p_tipo_documento character varying DEFAULT NULL::character varying, p_id_ficha integer DEFAULT NULL::integer, p_id_programa integer DEFAULT NULL::integer, p_nombre_aprendiz character varying DEFAULT NULL::character varying) RETURNS TABLE(documento character varying, tipo_documento character varying, nombre_completo text, codigo_ficha character varying, programa character varying, estado_matricula character varying, total_resultados bigint, aprobados bigint, pendientes bigint, no_aprobados bigint, porcentaje_avance numeric)
    LANGUAGE plpgsql
    AS $$
      BEGIN
          RETURN QUERY
          SELECT 
              a.documento, a.tipo_documento, (a.nombres || ' ' || a.apellidos)::TEXT,
              f.codigo_ficha, p.denominacion, ea.descripcion as estado_matricula,
              COUNT(ra.id_resultado),
              COUNT(je.id_juicio) FILTER (WHERE tj.codigo = 'AP'),
              COUNT(ra.id_resultado) - COUNT(je.id_juicio),
              COUNT(je.id_juicio) FILTER (WHERE tj.codigo = 'NA'),
              ROUND(COALESCE(COUNT(je.id_juicio) FILTER (WHERE tj.codigo = 'AP')::NUMERIC / NULLIF(COUNT(ra.id_resultado), 0) * 100, 0), 2)
          FROM aprendiz a
          JOIN matricula m ON a.documento = m.id_aprendiz
          LEFT JOIN estado_aprendiz ea ON m.id_estado = ea.id_estado
          JOIN ficha f ON m.id_ficha = f.id_ficha
          JOIN programa p ON f.id_programa = p.id
          JOIN competencia c ON p.id = c.id_programa
          JOIN resultado_aprendizaje ra ON c.id_competencia = ra.id_competencia
          LEFT JOIN juicios_evaluativos je ON m.id_matricula = je.id_matricula AND ra.id_resultado = je.id_resultado
          LEFT JOIN tipo_juicio tj ON je.id_tipo = tj.id
          WHERE (p_documento IS NULL OR a.documento = p_documento)
            AND (p_id_ficha IS NULL OR f.id_ficha = p_id_ficha)
            AND (p_id_programa IS NULL OR p.id = p_id_programa)
            AND (p_nombre_aprendiz IS NULL OR (a.nombres || ' ' || a.apellidos) ILIKE '%' || p_nombre_aprendiz || '%')
          GROUP BY a.documento, a.tipo_documento, a.nombres, a.apellidos, f.codigo_ficha, p.denominacion, ea.descripcion;
      END;
      $$;


ALTER FUNCTION public.fn_resultados_por_aprendiz(p_documento character varying, p_tipo_documento character varying, p_id_ficha integer, p_id_programa integer, p_nombre_aprendiz character varying) OWNER TO postgres;

--
-- Name: fn_resumen_funcionario(integer, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_resumen_funcionario(p_id_funcionario integer DEFAULT NULL::integer, p_cargo character varying DEFAULT NULL::character varying) RETURNS TABLE(id_funcionario integer, funcionario text, cargo character varying, total_juicios_registrados bigint, aprendices_evaluados bigint, aprobados bigint, no_aprobados bigint, primera_evaluacion date, ultima_evaluacion date)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        func.id_funcionario,
        CONCAT(func.nombres, ' ', func.apellidos) AS funcionario,
        func.cargo,
        COUNT(je.id_juicio) AS total_juicios_registrados,
        COUNT(DISTINCT je.id_matricula) AS aprendices_evaluados,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'AP' THEN je.id_juicio END) AS aprobados,
        COUNT(DISTINCT CASE WHEN tj.codigo = 'NA' THEN je.id_juicio END) AS no_aprobados,
        MIN(DATE(je.fecha)) AS primera_evaluacion,
        MAX(DATE(je.fecha)) AS ultima_evaluacion
    FROM funcionario func
    LEFT JOIN juicios_evaluativos je ON func.id_funcionario = je.id_funcionario
    LEFT JOIN tipo_juicio tj ON je.id_tipo = tj.id
    WHERE (p_id_funcionario IS NULL OR func.id_funcionario = p_id_funcionario)
      AND (p_cargo IS NULL OR func.cargo = p_cargo)
    GROUP BY func.id_funcionario, func.nombres, func.apellidos, func.cargo
    ORDER BY total_juicios_registrados DESC;
END;
$$;


ALTER FUNCTION public.fn_resumen_funcionario(p_id_funcionario integer, p_cargo character varying) OWNER TO postgres;

--
-- Name: fn_total_aprendices(integer, integer, integer, character varying, character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_total_aprendices(p_id_ficha integer DEFAULT NULL::integer, p_id_programa integer DEFAULT NULL::integer, p_version integer DEFAULT NULL::integer, p_nivel_formacion character varying DEFAULT NULL::character varying, p_estado_ficha character varying DEFAULT NULL::character varying) RETURNS TABLE(id_ficha integer, codigo_ficha character varying, programa character varying, total_aprendices bigint, total_fichas bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        f.id_ficha,
        f.codigo_ficha,
        p.denominacion AS programa,
        COUNT(DISTINCT m.id_aprendiz) AS total_aprendices,
        COUNT(DISTINCT f.id_ficha) AS total_fichas
    FROM ficha f
    JOIN programa p ON f.id_programa = p.id
    LEFT JOIN matricula m ON f.id_ficha = m.id_ficha
    WHERE (p_id_ficha IS NULL OR f.id_ficha = p_id_ficha)
      AND (p_id_programa IS NULL OR p.id = p_id_programa)
      AND (p_version IS NULL OR p.version = p_version)
      AND (p_nivel_formacion IS NULL OR p.nivel_formacion = p_nivel_formacion)
      AND (p_estado_ficha IS NULL OR f.estado_ficha = p_estado_ficha)
    GROUP BY f.id_ficha, f.codigo_ficha, p.denominacion;
END;
$$;


ALTER FUNCTION public.fn_total_aprendices(p_id_ficha integer, p_id_programa integer, p_version integer, p_nivel_formacion character varying, p_estado_ficha character varying) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: aprendiz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aprendiz (
    documento character varying(20) NOT NULL,
    tipo_documento character varying(15),
    nombres character varying(100),
    apellidos character varying(120),
    email character varying(100),
    telefono character varying(20),
    fecha_nacimiento date,
    genero character varying(10)
);


ALTER TABLE public.aprendiz OWNER TO postgres;

--
-- Name: competencia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.competencia (
    id_competencia integer NOT NULL,
    codigo_competencia character varying(50),
    nombre_competencia character varying(255),
    descripcion text,
    id_programa integer NOT NULL,
    duracion_horas integer
);


ALTER TABLE public.competencia OWNER TO postgres;

--
-- Name: competencia_id_competencia_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.competencia_id_competencia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.competencia_id_competencia_seq OWNER TO postgres;

--
-- Name: competencia_id_competencia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.competencia_id_competencia_seq OWNED BY public.competencia.id_competencia;


--
-- Name: estado_aprendiz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estado_aprendiz (
    id_estado integer NOT NULL,
    descripcion character varying(30) NOT NULL,
    codigo character varying(10)
);


ALTER TABLE public.estado_aprendiz OWNER TO postgres;

--
-- Name: estado_aprendiz_id_estado_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estado_aprendiz_id_estado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.estado_aprendiz_id_estado_seq OWNER TO postgres;

--
-- Name: estado_aprendiz_id_estado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.estado_aprendiz_id_estado_seq OWNED BY public.estado_aprendiz.id_estado;


--
-- Name: ficha; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ficha (
    id_ficha integer NOT NULL,
    codigo_ficha character varying(20),
    estado_ficha character varying(50),
    fecha_inicio date,
    fecha_fin date,
    id_programa integer NOT NULL
);


ALTER TABLE public.ficha OWNER TO postgres;

--
-- Name: funcionario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.funcionario (
    id_funcionario integer NOT NULL,
    tipo_documento character varying(10),
    numero_documento character varying(20),
    nombres character varying(255),
    apellidos character varying(255),
    cargo character varying(100),
    email character varying(100),
    estado character varying(20) DEFAULT 'Activo'::character varying
);


ALTER TABLE public.funcionario OWNER TO postgres;

--
-- Name: funcionario_id_funcionario_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.funcionario_id_funcionario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.funcionario_id_funcionario_seq OWNER TO postgres;

--
-- Name: funcionario_id_funcionario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.funcionario_id_funcionario_seq OWNED BY public.funcionario.id_funcionario;


--
-- Name: juicios_evaluativos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.juicios_evaluativos (
    id_juicio integer NOT NULL,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    observaciones text,
    id_matricula integer NOT NULL,
    id_resultado integer NOT NULL,
    id_tipo integer NOT NULL,
    id_funcionario integer
);


ALTER TABLE public.juicios_evaluativos OWNER TO postgres;

--
-- Name: juicios_evaluativos_id_juicio_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.juicios_evaluativos_id_juicio_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.juicios_evaluativos_id_juicio_seq OWNER TO postgres;

--
-- Name: juicios_evaluativos_id_juicio_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.juicios_evaluativos_id_juicio_seq OWNED BY public.juicios_evaluativos.id_juicio;


--
-- Name: matricula; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.matricula (
    id_matricula integer NOT NULL,
    fecha_ingreso date,
    fecha_retiro date,
    id_aprendiz character varying(20) NOT NULL,
    id_ficha integer NOT NULL,
    id_estado integer NOT NULL
);


ALTER TABLE public.matricula OWNER TO postgres;

--
-- Name: matricula_id_matricula_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.matricula_id_matricula_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.matricula_id_matricula_seq OWNER TO postgres;

--
-- Name: matricula_id_matricula_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.matricula_id_matricula_seq OWNED BY public.matricula.id_matricula;


--
-- Name: programa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.programa (
    id integer NOT NULL,
    codigo_programa character varying(20),
    denominacion character varying(255),
    version integer,
    nivel_formacion character varying(50),
    duracion_horas integer,
    estado character varying(20) DEFAULT 'Activo'::character varying
);


ALTER TABLE public.programa OWNER TO postgres;

--
-- Name: programa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.programa_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.programa_id_seq OWNER TO postgres;

--
-- Name: programa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.programa_id_seq OWNED BY public.programa.id;


--
-- Name: resultado_aprendizaje; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.resultado_aprendizaje (
    id_resultado integer NOT NULL,
    codigo_resultado character varying(50),
    descripcion text,
    id_competencia integer NOT NULL,
    duracion_horas integer
);


ALTER TABLE public.resultado_aprendizaje OWNER TO postgres;

--
-- Name: resultado_aprendizaje_id_resultado_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.resultado_aprendizaje_id_resultado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.resultado_aprendizaje_id_resultado_seq OWNER TO postgres;

--
-- Name: resultado_aprendizaje_id_resultado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.resultado_aprendizaje_id_resultado_seq OWNED BY public.resultado_aprendizaje.id_resultado;


--
-- Name: tipo_juicio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tipo_juicio (
    id integer NOT NULL,
    nombre character varying(20) NOT NULL,
    codigo character varying(10)
);


ALTER TABLE public.tipo_juicio OWNER TO postgres;

--
-- Name: tipo_juicio_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tipo_juicio_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tipo_juicio_id_seq OWNER TO postgres;

--
-- Name: tipo_juicio_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tipo_juicio_id_seq OWNED BY public.tipo_juicio.id;


--
-- Name: v_aprobacion_competencia; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_aprobacion_competencia AS
 SELECT p.denominacion AS programa,
    c.id_competencia,
    c.codigo_competencia,
    c.nombre_competencia,
    count(DISTINCT je.id_juicio) AS total_evaluaciones,
    count(DISTINCT
        CASE
            WHEN ((tj.codigo)::text = 'AP'::text) THEN je.id_juicio
            ELSE NULL::integer
        END) AS aprobados,
    round((((count(DISTINCT
        CASE
            WHEN ((tj.codigo)::text = 'AP'::text) THEN je.id_juicio
            ELSE NULL::integer
        END))::numeric * 100.0) / (NULLIF(count(DISTINCT je.id_juicio), 0))::numeric), 2) AS porcentaje_aprobacion
   FROM ((((public.competencia c
     JOIN public.programa p ON ((c.id_programa = p.id)))
     LEFT JOIN public.resultado_aprendizaje ra ON ((c.id_competencia = ra.id_competencia)))
     LEFT JOIN public.juicios_evaluativos je ON ((ra.id_resultado = je.id_resultado)))
     LEFT JOIN public.tipo_juicio tj ON ((je.id_tipo = tj.id)))
  GROUP BY p.denominacion, c.id_competencia, c.codigo_competencia, c.nombre_competencia;


ALTER VIEW public.v_aprobacion_competencia OWNER TO postgres;

--
-- Name: v_avance_aprendiz; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_avance_aprendiz AS
 SELECT a.documento,
    concat(a.nombres, ' ', a.apellidos) AS nombre_completo,
    f.codigo_ficha,
    p.denominacion AS programa,
    count(DISTINCT ra_total.id_resultado) AS total_resultados,
    count(DISTINCT
        CASE
            WHEN ((tj.codigo)::text = 'AP'::text) THEN ra_eval.id_resultado
            ELSE NULL::integer
        END) AS aprobados,
    round((((count(DISTINCT
        CASE
            WHEN ((tj.codigo)::text = 'AP'::text) THEN ra_eval.id_resultado
            ELSE NULL::integer
        END))::numeric * 100.0) / (NULLIF(count(DISTINCT ra_total.id_resultado), 0))::numeric), 2) AS porcentaje_avance
   FROM ((((((((public.aprendiz a
     JOIN public.matricula m ON (((a.documento)::text = (m.id_aprendiz)::text)))
     JOIN public.ficha f ON ((m.id_ficha = f.id_ficha)))
     JOIN public.programa p ON ((f.id_programa = p.id)))
     JOIN public.competencia c ON ((p.id = c.id_programa)))
     JOIN public.resultado_aprendizaje ra_total ON ((c.id_competencia = ra_total.id_competencia)))
     LEFT JOIN public.juicios_evaluativos je ON ((m.id_matricula = je.id_matricula)))
     LEFT JOIN public.resultado_aprendizaje ra_eval ON ((je.id_resultado = ra_eval.id_resultado)))
     LEFT JOIN public.tipo_juicio tj ON ((je.id_tipo = tj.id)))
  GROUP BY a.documento, a.nombres, a.apellidos, f.codigo_ficha, p.denominacion;


ALTER VIEW public.v_avance_aprendiz OWNER TO postgres;

--
-- Name: v_estado_matriculas; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_estado_matriculas AS
 SELECT ea.descripcion AS estado,
    count(DISTINCT m.id_matricula) AS total_matriculas,
    count(DISTINCT m.id_aprendiz) AS total_aprendices,
    round((((count(DISTINCT m.id_matricula))::numeric * 100.0) / (NULLIF(( SELECT count(*) AS count
           FROM public.matricula), 0))::numeric), 2) AS porcentaje
   FROM (public.estado_aprendiz ea
     LEFT JOIN public.matricula m ON ((ea.id_estado = m.id_estado)))
  GROUP BY ea.id_estado, ea.descripcion;


ALTER VIEW public.v_estado_matriculas OWNER TO postgres;

--
-- Name: v_juicios_funcionario; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_juicios_funcionario AS
 SELECT func.id_funcionario,
    concat(func.nombres, ' ', func.apellidos) AS funcionario,
    func.cargo,
    count(je.id_juicio) AS total_juicios,
    count(DISTINCT
        CASE
            WHEN ((tj.codigo)::text = 'AP'::text) THEN je.id_juicio
            ELSE NULL::integer
        END) AS aprobados,
    count(DISTINCT
        CASE
            WHEN ((tj.codigo)::text = 'NA'::text) THEN je.id_juicio
            ELSE NULL::integer
        END) AS no_aprobados,
    count(DISTINCT
        CASE
            WHEN ((tj.codigo)::text = 'PE'::text) THEN je.id_juicio
            ELSE NULL::integer
        END) AS pendientes
   FROM ((public.funcionario func
     LEFT JOIN public.juicios_evaluativos je ON ((func.id_funcionario = je.id_funcionario)))
     LEFT JOIN public.tipo_juicio tj ON ((je.id_tipo = tj.id)))
  GROUP BY func.id_funcionario, func.nombres, func.apellidos, func.cargo;


ALTER VIEW public.v_juicios_funcionario OWNER TO postgres;

--
-- Name: v_resumen_general; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.v_resumen_general AS
 WITH juicio_aprobado AS (
         SELECT tipo_juicio.id
           FROM public.tipo_juicio
          WHERE (((tipo_juicio.nombre)::text ~~* '%aprobado%'::text) AND ((tipo_juicio.nombre)::text !~~* '%no%'::text))
        ), juicio_pendiente AS (
         SELECT tipo_juicio.id
           FROM public.tipo_juicio
          WHERE (((tipo_juicio.nombre)::text ~~* '%evaluar%'::text) OR ((tipo_juicio.nombre)::text ~~* '%pendiente%'::text))
        )
 SELECT ( SELECT count(DISTINCT aprendiz.documento) AS count
           FROM public.aprendiz) AS total_aprendices,
    ( SELECT count(DISTINCT m.id_aprendiz) AS count
           FROM (public.matricula m
             JOIN public.estado_aprendiz ea ON ((ea.id_estado = m.id_estado)))
          WHERE ((ea.descripcion)::text ~~* '%formaci%'::text)) AS aprendices_en_formacion,
    ( SELECT count(*) AS count
           FROM public.ficha) AS total_fichas,
    ( SELECT count(*) AS count
           FROM public.programa
          WHERE ((programa.estado)::text = 'Activo'::text)) AS total_programas,
    ( SELECT count(*) AS count
           FROM public.juicios_evaluativos) AS total_juicios,
    ( SELECT count(*) AS count
           FROM public.juicios_evaluativos
          WHERE (juicios_evaluativos.id_tipo IN ( SELECT juicio_aprobado.id
                   FROM juicio_aprobado))) AS juicios_aprobados,
    ( SELECT count(*) AS count
           FROM public.juicios_evaluativos
          WHERE (juicios_evaluativos.id_tipo IN ( SELECT juicio_pendiente.id
                   FROM juicio_pendiente))) AS juicios_pendientes,
        CASE
            WHEN (( SELECT count(*) AS count
               FROM public.juicios_evaluativos) = 0) THEN (0)::numeric
            ELSE round(((100.0 * (( SELECT count(*) AS count
               FROM public.juicios_evaluativos
              WHERE (juicios_evaluativos.id_tipo IN ( SELECT juicio_aprobado.id
                       FROM juicio_aprobado))))::numeric) / (( SELECT count(*) AS count
               FROM public.juicios_evaluativos))::numeric), 2)
        END AS porcentaje_avance_global,
    ( SELECT count(*) AS count
           FROM public.funcionario
          WHERE ((funcionario.estado)::text = 'Activo'::text)) AS total_funcionarios;


ALTER VIEW public.v_resumen_general OWNER TO postgres;

--
-- Name: competencia id_competencia; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.competencia ALTER COLUMN id_competencia SET DEFAULT nextval('public.competencia_id_competencia_seq'::regclass);


--
-- Name: estado_aprendiz id_estado; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estado_aprendiz ALTER COLUMN id_estado SET DEFAULT nextval('public.estado_aprendiz_id_estado_seq'::regclass);


--
-- Name: funcionario id_funcionario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.funcionario ALTER COLUMN id_funcionario SET DEFAULT nextval('public.funcionario_id_funcionario_seq'::regclass);


--
-- Name: juicios_evaluativos id_juicio; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos ALTER COLUMN id_juicio SET DEFAULT nextval('public.juicios_evaluativos_id_juicio_seq'::regclass);


--
-- Name: matricula id_matricula; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matricula ALTER COLUMN id_matricula SET DEFAULT nextval('public.matricula_id_matricula_seq'::regclass);


--
-- Name: programa id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.programa ALTER COLUMN id SET DEFAULT nextval('public.programa_id_seq'::regclass);


--
-- Name: resultado_aprendizaje id_resultado; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resultado_aprendizaje ALTER COLUMN id_resultado SET DEFAULT nextval('public.resultado_aprendizaje_id_resultado_seq'::regclass);


--
-- Name: tipo_juicio id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_juicio ALTER COLUMN id SET DEFAULT nextval('public.tipo_juicio_id_seq'::regclass);


--
-- Name: aprendiz aprendiz_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprendiz
    ADD CONSTRAINT aprendiz_pkey PRIMARY KEY (documento);


--
-- Name: competencia competencia_codigo_competencia_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.competencia
    ADD CONSTRAINT competencia_codigo_competencia_key UNIQUE (codigo_competencia);


--
-- Name: competencia competencia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.competencia
    ADD CONSTRAINT competencia_pkey PRIMARY KEY (id_competencia);


--
-- Name: estado_aprendiz estado_aprendiz_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estado_aprendiz
    ADD CONSTRAINT estado_aprendiz_codigo_key UNIQUE (codigo);


--
-- Name: estado_aprendiz estado_aprendiz_descripcion_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estado_aprendiz
    ADD CONSTRAINT estado_aprendiz_descripcion_key UNIQUE (descripcion);


--
-- Name: estado_aprendiz estado_aprendiz_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estado_aprendiz
    ADD CONSTRAINT estado_aprendiz_pkey PRIMARY KEY (id_estado);


--
-- Name: ficha ficha_codigo_ficha_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ficha
    ADD CONSTRAINT ficha_codigo_ficha_key UNIQUE (codigo_ficha);


--
-- Name: ficha ficha_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ficha
    ADD CONSTRAINT ficha_pkey PRIMARY KEY (id_ficha);


--
-- Name: funcionario funcionario_numero_documento_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.funcionario
    ADD CONSTRAINT funcionario_numero_documento_key UNIQUE (numero_documento);


--
-- Name: funcionario funcionario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.funcionario
    ADD CONSTRAINT funcionario_pkey PRIMARY KEY (id_funcionario);


--
-- Name: juicios_evaluativos juicios_evaluativos_id_matricula_id_resultado_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos
    ADD CONSTRAINT juicios_evaluativos_id_matricula_id_resultado_key UNIQUE (id_matricula, id_resultado);


--
-- Name: juicios_evaluativos juicios_evaluativos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos
    ADD CONSTRAINT juicios_evaluativos_pkey PRIMARY KEY (id_juicio);


--
-- Name: matricula matricula_id_aprendiz_id_ficha_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT matricula_id_aprendiz_id_ficha_key UNIQUE (id_aprendiz, id_ficha);


--
-- Name: matricula matricula_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT matricula_pkey PRIMARY KEY (id_matricula);


--
-- Name: programa programa_codigo_programa_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.programa
    ADD CONSTRAINT programa_codigo_programa_key UNIQUE (codigo_programa);


--
-- Name: programa programa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.programa
    ADD CONSTRAINT programa_pkey PRIMARY KEY (id);


--
-- Name: resultado_aprendizaje resultado_aprendizaje_codigo_resultado_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resultado_aprendizaje
    ADD CONSTRAINT resultado_aprendizaje_codigo_resultado_key UNIQUE (codigo_resultado);


--
-- Name: resultado_aprendizaje resultado_aprendizaje_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resultado_aprendizaje
    ADD CONSTRAINT resultado_aprendizaje_pkey PRIMARY KEY (id_resultado);


--
-- Name: tipo_juicio tipo_juicio_codigo_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_juicio
    ADD CONSTRAINT tipo_juicio_codigo_key UNIQUE (codigo);


--
-- Name: tipo_juicio tipo_juicio_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_juicio
    ADD CONSTRAINT tipo_juicio_nombre_key UNIQUE (nombre);


--
-- Name: tipo_juicio tipo_juicio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tipo_juicio
    ADD CONSTRAINT tipo_juicio_pkey PRIMARY KEY (id);


--
-- Name: idx_aprendiz_nombres; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_aprendiz_nombres ON public.aprendiz USING btree (nombres, apellidos);


--
-- Name: idx_competencia_programa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_competencia_programa ON public.competencia USING btree (id_programa);


--
-- Name: idx_ficha_programa; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ficha_programa ON public.ficha USING btree (id_programa);


--
-- Name: idx_funcionario_nombre; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_funcionario_nombre ON public.funcionario USING btree (nombres, apellidos);


--
-- Name: idx_juicios_fecha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_juicios_fecha ON public.juicios_evaluativos USING btree (fecha);


--
-- Name: idx_juicios_funcionario; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_juicios_funcionario ON public.juicios_evaluativos USING btree (id_funcionario);


--
-- Name: idx_juicios_matricula; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_juicios_matricula ON public.juicios_evaluativos USING btree (id_matricula);


--
-- Name: idx_juicios_resultado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_juicios_resultado ON public.juicios_evaluativos USING btree (id_resultado);


--
-- Name: idx_juicios_tipo; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_juicios_tipo ON public.juicios_evaluativos USING btree (id_tipo);


--
-- Name: idx_matricula_aprendiz; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_matricula_aprendiz ON public.matricula USING btree (id_aprendiz);


--
-- Name: idx_matricula_estado; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_matricula_estado ON public.matricula USING btree (id_estado);


--
-- Name: idx_matricula_ficha; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_matricula_ficha ON public.matricula USING btree (id_ficha);


--
-- Name: idx_resultado_competencia; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_resultado_competencia ON public.resultado_aprendizaje USING btree (id_competencia);


--
-- Name: competencia competencia_id_programa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.competencia
    ADD CONSTRAINT competencia_id_programa_fkey FOREIGN KEY (id_programa) REFERENCES public.programa(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: ficha ficha_id_programa_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ficha
    ADD CONSTRAINT ficha_id_programa_fkey FOREIGN KEY (id_programa) REFERENCES public.programa(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: juicios_evaluativos juicios_evaluativos_id_funcionario_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos
    ADD CONSTRAINT juicios_evaluativos_id_funcionario_fkey FOREIGN KEY (id_funcionario) REFERENCES public.funcionario(id_funcionario) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: juicios_evaluativos juicios_evaluativos_id_matricula_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos
    ADD CONSTRAINT juicios_evaluativos_id_matricula_fkey FOREIGN KEY (id_matricula) REFERENCES public.matricula(id_matricula) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: juicios_evaluativos juicios_evaluativos_id_resultado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos
    ADD CONSTRAINT juicios_evaluativos_id_resultado_fkey FOREIGN KEY (id_resultado) REFERENCES public.resultado_aprendizaje(id_resultado) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: juicios_evaluativos juicios_evaluativos_id_tipo_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos
    ADD CONSTRAINT juicios_evaluativos_id_tipo_fkey FOREIGN KEY (id_tipo) REFERENCES public.tipo_juicio(id) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: matricula matricula_id_aprendiz_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT matricula_id_aprendiz_fkey FOREIGN KEY (id_aprendiz) REFERENCES public.aprendiz(documento) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: matricula matricula_id_estado_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT matricula_id_estado_fkey FOREIGN KEY (id_estado) REFERENCES public.estado_aprendiz(id_estado) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: matricula matricula_id_ficha_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.matricula
    ADD CONSTRAINT matricula_id_ficha_fkey FOREIGN KEY (id_ficha) REFERENCES public.ficha(id_ficha) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- Name: resultado_aprendizaje resultado_aprendizaje_id_competencia_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resultado_aprendizaje
    ADD CONSTRAINT resultado_aprendizaje_id_competencia_fkey FOREIGN KEY (id_competencia) REFERENCES public.competencia(id_competencia) ON UPDATE CASCADE ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

\unrestrict HNSSc9kAOfTWUEmbdDfQJ44m2fWc4yYTmECuKRj3dkPGGK4oN3tfFVAXxzWdClj

