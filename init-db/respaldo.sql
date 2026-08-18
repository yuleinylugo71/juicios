--
-- PostgreSQL database dump
--

\restrict V2bor6T90ZzsBADGKLPEX5dtIdwwjyWSXI1fMHL1pjqp65jOT4ohdvSeKxiwdfC

-- Dumped from database version 18.2
-- Dumped by pg_dump version 18.2

SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: aprendices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aprendices (
    id_aprendiz integer NOT NULL,
    tipo_documento character varying(20),
    numero_documento character varying(30),
    nombres character varying(100),
    apellidos character varying(100),
    estado character varying(30),
    id_programa integer
);


ALTER TABLE public.aprendices OWNER TO postgres;

--
-- Name: aprendices_id_aprendiz_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aprendices_id_aprendiz_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.aprendices_id_aprendiz_seq OWNER TO postgres;

--
-- Name: aprendices_id_aprendiz_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aprendices_id_aprendiz_seq OWNED BY public.aprendices.id_aprendiz;


--
-- Name: aprendiz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.aprendiz (
    id integer NOT NULL,
    documento text,
    nombre text,
    estado text,
    programa_id integer
);


ALTER TABLE public.aprendiz OWNER TO postgres;

--
-- Name: aprendiz_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.aprendiz_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.aprendiz_id_seq OWNER TO postgres;

--
-- Name: aprendiz_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.aprendiz_id_seq OWNED BY public.aprendiz.id;


--
-- Name: competencia; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.competencia (
    id integer NOT NULL,
    nombre text
);


ALTER TABLE public.competencia OWNER TO postgres;

--
-- Name: competencia_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.competencia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.competencia_id_seq OWNER TO postgres;

--
-- Name: competencia_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.competencia_id_seq OWNED BY public.competencia.id;


--
-- Name: competencias; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.competencias (
    id_competencia integer NOT NULL,
    nombre character varying(255)
);


ALTER TABLE public.competencias OWNER TO postgres;

--
-- Name: competencias_id_competencia_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.competencias_id_competencia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.competencias_id_competencia_seq OWNER TO postgres;

--
-- Name: competencias_id_competencia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.competencias_id_competencia_seq OWNED BY public.competencias.id_competencia;


--
-- Name: funcionario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.funcionario (
    id integer NOT NULL,
    nombre text
);


ALTER TABLE public.funcionario OWNER TO postgres;

--
-- Name: funcionario_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.funcionario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.funcionario_id_seq OWNER TO postgres;

--
-- Name: funcionario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.funcionario_id_seq OWNED BY public.funcionario.id;


--
-- Name: funcionarios; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.funcionarios (
    id_funcionario integer NOT NULL,
    nombre character varying(255)
);


ALTER TABLE public.funcionarios OWNER TO postgres;

--
-- Name: funcionarios_id_funcionario_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.funcionarios_id_funcionario_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.funcionarios_id_funcionario_seq OWNER TO postgres;

--
-- Name: funcionarios_id_funcionario_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.funcionarios_id_funcionario_seq OWNED BY public.funcionarios.id_funcionario;


--
-- Name: juicio; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.juicio (
    id integer NOT NULL,
    aprendiz_id integer,
    resultado_id integer,
    funcionario_id integer,
    valoracion text,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.juicio OWNER TO postgres;

--
-- Name: juicio_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.juicio_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.juicio_id_seq OWNER TO postgres;

--
-- Name: juicio_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.juicio_id_seq OWNED BY public.juicio.id;


--
-- Name: juicios_evaluativos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.juicios_evaluativos (
    id_juicio integer NOT NULL,
    id_aprendiz integer,
    id_resultado integer,
    id_funcionario integer,
    juicio character varying(50),
    fecha_hora timestamp without time zone DEFAULT CURRENT_TIMESTAMP
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
-- Name: programa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.programa (
    id integer NOT NULL,
    nombre text
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
-- Name: programas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.programas (
    id_programa integer NOT NULL,
    ficha character varying(20),
    codigo_programa character varying(20),
    nombre_programa character varying(255)
);


ALTER TABLE public.programas OWNER TO postgres;

--
-- Name: programas_id_programa_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.programas_id_programa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.programas_id_programa_seq OWNER TO postgres;

--
-- Name: programas_id_programa_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.programas_id_programa_seq OWNED BY public.programas.id_programa;


--
-- Name: resultado_aprendizaje; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.resultado_aprendizaje (
    id integer NOT NULL,
    nombre text,
    competencia_id integer
);


ALTER TABLE public.resultado_aprendizaje OWNER TO postgres;

--
-- Name: resultado_aprendizaje_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.resultado_aprendizaje_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.resultado_aprendizaje_id_seq OWNER TO postgres;

--
-- Name: resultado_aprendizaje_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.resultado_aprendizaje_id_seq OWNED BY public.resultado_aprendizaje.id;


--
-- Name: resultados_aprendizaje; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.resultados_aprendizaje (
    id_resultado integer NOT NULL,
    descripcion text,
    id_competencia integer
);


ALTER TABLE public.resultados_aprendizaje OWNER TO postgres;

--
-- Name: resultados_aprendizaje_id_resultado_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.resultados_aprendizaje_id_resultado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.resultados_aprendizaje_id_resultado_seq OWNER TO postgres;

--
-- Name: resultados_aprendizaje_id_resultado_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.resultados_aprendizaje_id_resultado_seq OWNED BY public.resultados_aprendizaje.id_resultado;


--
-- Name: aprendices id_aprendiz; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprendices ALTER COLUMN id_aprendiz SET DEFAULT nextval('public.aprendices_id_aprendiz_seq'::regclass);


--
-- Name: aprendiz id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprendiz ALTER COLUMN id SET DEFAULT nextval('public.aprendiz_id_seq'::regclass);


--
-- Name: competencia id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.competencia ALTER COLUMN id SET DEFAULT nextval('public.competencia_id_seq'::regclass);


--
-- Name: competencias id_competencia; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.competencias ALTER COLUMN id_competencia SET DEFAULT nextval('public.competencias_id_competencia_seq'::regclass);


--
-- Name: funcionario id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.funcionario ALTER COLUMN id SET DEFAULT nextval('public.funcionario_id_seq'::regclass);


--
-- Name: funcionarios id_funcionario; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.funcionarios ALTER COLUMN id_funcionario SET DEFAULT nextval('public.funcionarios_id_funcionario_seq'::regclass);


--
-- Name: juicio id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicio ALTER COLUMN id SET DEFAULT nextval('public.juicio_id_seq'::regclass);


--
-- Name: juicios_evaluativos id_juicio; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos ALTER COLUMN id_juicio SET DEFAULT nextval('public.juicios_evaluativos_id_juicio_seq'::regclass);


--
-- Name: programa id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.programa ALTER COLUMN id SET DEFAULT nextval('public.programa_id_seq'::regclass);


--
-- Name: programas id_programa; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.programas ALTER COLUMN id_programa SET DEFAULT nextval('public.programas_id_programa_seq'::regclass);


--
-- Name: resultado_aprendizaje id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resultado_aprendizaje ALTER COLUMN id SET DEFAULT nextval('public.resultado_aprendizaje_id_seq'::regclass);


--
-- Name: resultados_aprendizaje id_resultado; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resultados_aprendizaje ALTER COLUMN id_resultado SET DEFAULT nextval('public.resultados_aprendizaje_id_resultado_seq'::regclass);


--
-- Name: aprendices aprendices_numero_documento_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprendices
    ADD CONSTRAINT aprendices_numero_documento_key UNIQUE (numero_documento);


--
-- Name: aprendices aprendices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprendices
    ADD CONSTRAINT aprendices_pkey PRIMARY KEY (id_aprendiz);


--
-- Name: aprendiz aprendiz_documento_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprendiz
    ADD CONSTRAINT aprendiz_documento_key UNIQUE (documento);


--
-- Name: aprendiz aprendiz_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprendiz
    ADD CONSTRAINT aprendiz_pkey PRIMARY KEY (id);


--
-- Name: competencia competencia_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.competencia
    ADD CONSTRAINT competencia_nombre_key UNIQUE (nombre);


--
-- Name: competencia competencia_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.competencia
    ADD CONSTRAINT competencia_pkey PRIMARY KEY (id);


--
-- Name: competencias competencias_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.competencias
    ADD CONSTRAINT competencias_nombre_key UNIQUE (nombre);


--
-- Name: competencias competencias_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.competencias
    ADD CONSTRAINT competencias_pkey PRIMARY KEY (id_competencia);


--
-- Name: funcionario funcionario_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.funcionario
    ADD CONSTRAINT funcionario_nombre_key UNIQUE (nombre);


--
-- Name: funcionario funcionario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.funcionario
    ADD CONSTRAINT funcionario_pkey PRIMARY KEY (id);


--
-- Name: funcionarios funcionarios_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.funcionarios
    ADD CONSTRAINT funcionarios_nombre_key UNIQUE (nombre);


--
-- Name: funcionarios funcionarios_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.funcionarios
    ADD CONSTRAINT funcionarios_pkey PRIMARY KEY (id_funcionario);


--
-- Name: juicio juicio_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicio
    ADD CONSTRAINT juicio_pkey PRIMARY KEY (id);


--
-- Name: juicios_evaluativos juicios_evaluativos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos
    ADD CONSTRAINT juicios_evaluativos_pkey PRIMARY KEY (id_juicio);


--
-- Name: programa programa_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.programa
    ADD CONSTRAINT programa_nombre_key UNIQUE (nombre);


--
-- Name: programa programa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.programa
    ADD CONSTRAINT programa_pkey PRIMARY KEY (id);


--
-- Name: programas programas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.programas
    ADD CONSTRAINT programas_pkey PRIMARY KEY (id_programa);


--
-- Name: resultado_aprendizaje resultado_aprendizaje_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resultado_aprendizaje
    ADD CONSTRAINT resultado_aprendizaje_pkey PRIMARY KEY (id);


--
-- Name: resultados_aprendizaje resultados_aprendizaje_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resultados_aprendizaje
    ADD CONSTRAINT resultados_aprendizaje_pkey PRIMARY KEY (id_resultado);


--
-- Name: aprendiz aprendiz_programa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprendiz
    ADD CONSTRAINT aprendiz_programa_id_fkey FOREIGN KEY (programa_id) REFERENCES public.programa(id);


--
-- Name: juicios_evaluativos fk_aprendiz; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos
    ADD CONSTRAINT fk_aprendiz FOREIGN KEY (id_aprendiz) REFERENCES public.aprendices(id_aprendiz);


--
-- Name: resultados_aprendizaje fk_competencia; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resultados_aprendizaje
    ADD CONSTRAINT fk_competencia FOREIGN KEY (id_competencia) REFERENCES public.competencias(id_competencia) ON DELETE CASCADE;


--
-- Name: juicios_evaluativos fk_funcionario; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos
    ADD CONSTRAINT fk_funcionario FOREIGN KEY (id_funcionario) REFERENCES public.funcionarios(id_funcionario);


--
-- Name: aprendices fk_programa; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.aprendices
    ADD CONSTRAINT fk_programa FOREIGN KEY (id_programa) REFERENCES public.programas(id_programa) ON DELETE SET NULL;


--
-- Name: juicios_evaluativos fk_resultado; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicios_evaluativos
    ADD CONSTRAINT fk_resultado FOREIGN KEY (id_resultado) REFERENCES public.resultados_aprendizaje(id_resultado);


--
-- Name: juicio juicio_aprendiz_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicio
    ADD CONSTRAINT juicio_aprendiz_id_fkey FOREIGN KEY (aprendiz_id) REFERENCES public.aprendiz(id);


--
-- Name: juicio juicio_funcionario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicio
    ADD CONSTRAINT juicio_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES public.funcionario(id);


--
-- Name: juicio juicio_resultado_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.juicio
    ADD CONSTRAINT juicio_resultado_id_fkey FOREIGN KEY (resultado_id) REFERENCES public.resultado_aprendizaje(id);


--
-- Name: resultado_aprendizaje resultado_aprendizaje_competencia_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.resultado_aprendizaje
    ADD CONSTRAINT resultado_aprendizaje_competencia_id_fkey FOREIGN KEY (competencia_id) REFERENCES public.competencia(id);


--
-- PostgreSQL database dump complete
--

\unrestrict V2bor6T90ZzsBADGKLPEX5dtIdwwjyWSXI1fMHL1pjqp65jOT4ohdvSeKxiwdfC

