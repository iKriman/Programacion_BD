-- TRABAJO FORMATIVO S1 PROGRAMACION PARA BASE DE DATOS.
-- GRUPO 14

-- ==========================================
-- CASO 1: PROCESO CLIENTE TODOSUMA
-- ==========================================

-- dejamos opcion para que el resultado pueda salir en consola
SET SERVEROUTPUT ON;

-- variables BIND
VARIABLE b_run NUMBER;
VARIABLE b_pnormal NUMBER;
VARIABLE b_extra1 NUMBER;
VARIABLE b_extra2 NUMBER;
VARIABLE b_extra3 NUMBER;

-- asignacion de valores para la prueba
-- (8333032, 14423721, 14439730, 22558061)
EXEC :b_run := 14439730; 
EXEC :b_pnormal := 1200;
EXEC :b_extra1 := 100;
EXEC :b_extra2 := 300;
EXEC :b_extra3 := 550;

DECLARE
    -- variables escalares para almacenar informacion del cliente
    v_nro_cliente    cliente.nro_cliente%TYPE;
    v_nombre_full    VARCHAR2(250);
    v_tipo_cliente   tipo_cliente.nombre_tipo_cliente%TYPE;
    v_dv_run         cliente.dvrun%TYPE;
    
    -- Variables para calculos financieros
    v_monto_anual    NUMBER := 0;
    v_pesos_base     NUMBER := 0;
    v_pesos_extra    NUMBER := 0;
    v_pesos_totales  NUMBER := 0;
    
    -- Variable para año anterior de forma dinamica 
    v_annio_proceso  NUMBER := EXTRACT(YEAR FROM SYSDATE) - 1;
BEGIN
    -- recuperacion de datos del cliente y su tipo (JOIN con TIPO_CLIENTE)
    -- usamos SELECT para traspasar los datos de las columnas a las variables
    SELECT c.nro_cliente, 
           c.pnombre || ' ' || c.appaterno || ' ' || c.apmaterno,
           tc.nombre_tipo_cliente,
           c.dvrun
    INTO v_nro_cliente, v_nombre_full, v_tipo_cliente, v_dv_run
    FROM cliente c
    JOIN tipo_cliente tc ON c.cod_tipo_cliente = tc.cod_tipo_cliente
    WHERE c.numrun = :b_run;

    -- suma del monto total de creditos solicitados el año anterior
    -- Se usa NVL para que si el cliente no tiene creditos el valor sea 0 y no NULL
    SELECT NVL(SUM(monto_solicitado), 0)
    INTO v_monto_anual
    FROM credito_cliente
    WHERE nro_cliente = v_nro_cliente
      AND EXTRACT(YEAR FROM fecha_solic_cred) = v_annio_proceso;

    -- calculo de pesos (1.200 por cada 100.000)
    -- Se usa TRUNC para obtener la cantidad de veces exactas que cabe 100.000 en el monto
    v_pesos_base := TRUNC(v_monto_anual / 100000) * :b_pnormal;

    -- calculo de pesos extra segun tipo de cliente y tramos de monto
    -- solo aplica para trabajadores independientes
    IF v_tipo_cliente = 'Trabajadores independientes' THEN
        IF v_monto_anual <= 1000000 THEN
            v_pesos_extra := TRUNC(v_monto_anual / 100000) * :b_extra1;
        ELSIF v_monto_anual <= 3000000 THEN
            v_pesos_extra := TRUNC(v_monto_anual / 100000) * :b_extra2;
        ELSE
            v_pesos_extra := TRUNC(v_monto_anual / 100000) * :b_extra3;
        END IF;
    END IF;

    -- suma total de pesos ganados
    v_pesos_totales := v_pesos_base + v_pesos_extra;

    -- insercion de resultados en la tabla CLIENTE_TODOSUMA
    -- primero se limpia el registro si existía para permitir re-ejecucion del codigo
    DELETE FROM cliente_todosuma WHERE nro_cliente = v_nro_cliente;
    
    INSERT INTO cliente_todosuma (
        nro_cliente, run_cliente, nombre_cliente, tipo_cliente, 
        monto_solic_creditos, monto_pesos_todosuma
    ) VALUES (
        v_nro_cliente, 
        :b_run || '-' || v_dv_run, 
        v_nombre_full, 
        v_tipo_cliente, 
        v_monto_anual, 
        v_pesos_totales
    );

    -- confirmacion del proceso por consola
    DBMS_OUTPUT.PUT_LINE('Proceso finalizado para el cliente: ' || v_nombre_full);
    DBMS_OUTPUT.PUT_LINE('Monto créditos ' || v_annio_proceso || ': $' || v_monto_anual);
    DBMS_OUTPUT.PUT_LINE('Total Pesos TODOSUMA: ' || v_pesos_totales);

    -- guarda los cambios en la base de datos
    COMMIT; 

-- manejo de exepciones
EXCEPTION
    -- manejo de error si el RUN no existe
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: El RUN ' || :b_run || ' no se encuentra en la base de datos.');
    -- manejo de cualquier otro error imprevisto
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR INESPERADO: ' || SQLERRM);
END;
/

-- select para revisar la tabla actualizada
SELECT * FROM cliente_todosuma;


-- ==========================================
-- CASO 2: POSTERGACION DE CUOTAS DE CREDITO
-- ==========================================

-- variables BIND
VARIABLE b_run NUMBER;
VARIABLE b_nro_solic NUMBER;
VARIABLE b_cuotas_post NUMBER;

-- personajes de prueba
-- (8333032, 14423721, 14439730)
-- Sebastián: 2001 / 2
-- Karen:     3004 / 1
-- Julián:    2004 / 1
EXEC :b_run := 14423721; 
EXEC :b_nro_solic := 2001;
EXEC :b_cuotas_post := 2;

DECLARE
    
    v_tipo_credito   credito.nombre_credito%TYPE;
    v_interes        NUMBER := 0;

   
    v_nro_cuota      NUMBER;
    v_fec_venc       DATE;
    v_valor_cuota    NUMBER;

 
    v_nro_cliente    cliente.nro_cliente%TYPE;

    
    v_es_recurrente  NUMBER;
BEGIN
    -- obtener numero interno del cliente
    SELECT nro_cliente
    INTO v_nro_cliente
    FROM cliente
    WHERE numrun = :b_run;

    -- obtener tipo de credito y ultima cuota ORIGINAL
    SELECT cr.nombre_credito,
           MAX(cu.nro_cuota),
           MAX(cu.fecha_venc_cuota),
           MAX(cu.valor_cuota)
    INTO v_tipo_credito, v_nro_cuota, v_fec_venc, v_valor_cuota
    FROM credito_cliente cc
    JOIN credito cr ON cc.cod_credito = cr.cod_credito
    JOIN cuota_credito_cliente cu ON cc.nro_solic_credito = cu.nro_solic_credito
    WHERE cc.nro_solic_credito = :b_nro_solic
    GROUP BY cr.nombre_credito;

    -- definir tasa segun tipo de credito y cuotas
    IF v_tipo_credito LIKE '%Hipotecario%' THEN
        IF :b_cuotas_post = 1 THEN
            v_interes := 0;
        ELSIF :b_cuotas_post = 2 THEN
            v_interes := 0.005;
        END IF;
    ELSIF v_tipo_credito LIKE '%Consumo%' THEN
        v_interes := 0.01;
    ELSIF v_tipo_credito LIKE '%Automotriz%' THEN
        v_interes := 0.02;
    END IF;

    -- verificar condonacion (mas de un credito historico)
    SELECT COUNT(*)
    INTO v_es_recurrente
    FROM credito_cliente
    WHERE nro_cliente = v_nro_cliente;

    IF v_es_recurrente > 1 THEN
        UPDATE cuota_credito_cliente
        SET fecha_pago_cuota = v_fec_venc,
            monto_pagado     = v_valor_cuota
        WHERE nro_solic_credito = :b_nro_solic
          AND nro_cuota = v_nro_cuota;

        DBMS_OUTPUT.PUT_LINE('SISTEMA: Condonación aplicada a cuota N° ' || v_nro_cuota);
    END IF;

    -- generacion de nuevas cuotas
    DBMS_OUTPUT.PUT_LINE('PERSONAJE PROCESADO: ' || v_tipo_credito);

    FOR i IN 1..:b_cuotas_post LOOP
        v_nro_cuota   := v_nro_cuota + 1;
        v_fec_venc    := ADD_MONTHS(v_fec_venc, 1);
        v_valor_cuota := v_valor_cuota * (1 + v_interes);

        INSERT INTO cuota_credito_cliente (
            nro_solic_credito,
            nro_cuota,
            fecha_venc_cuota,
            valor_cuota,
            fecha_pago_cuota,
            monto_pagado,
            saldo_por_pagar,
            cod_forma_pago
        ) VALUES (
            :b_nro_solic,
            v_nro_cuota,
            v_fec_venc,
            ROUND(v_valor_cuota),
            NULL,
            NULL,
            NULL,
            NULL
        );

        -- mostramos el resultado 
        DBMS_OUTPUT.PUT_LINE('-------------------------------------------');
        DBMS_OUTPUT.PUT_LINE('NRO_SOLIC_CREDITO : ' || :b_nro_solic);
        DBMS_OUTPUT.PUT_LINE('NRO_CUOTA         : ' || v_nro_cuota);
        DBMS_OUTPUT.PUT_LINE('FECHA_VENC_CUOTA  : ' || TO_CHAR(v_fec_venc,'DD/MM/YYYY'));
        DBMS_OUTPUT.PUT_LINE('VALOR_CUOTA       : ' || ROUND(v_valor_cuota));
        DBMS_OUTPUT.PUT_LINE('FECHA_PAGO_CUOTA  : NULL');
        DBMS_OUTPUT.PUT_LINE('MONTO_PAGADO      : NULL');
        DBMS_OUTPUT.PUT_LINE('SALDO_POR_PAGAR   : NULL');
        DBMS_OUTPUT.PUT_LINE('COD_FORMA_PAGO    : NULL');
    END LOOP;

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: Cliente o crédito no encontrado.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ERROR: ' || SQLERRM);
        ROLLBACK;
END;
/



-- select especializado para revisarlo como tabla
SELECT
    nro_solic_credito   AS "NRO_SOLIC_CREDITO",
    nro_cuota           AS "NRO_CUOTA",
    TO_CHAR(fecha_venc_cuota,'DD/MM/YYYY') AS "FECHA_VENC_CUOTA",
    valor_cuota         AS "VALOR_CUOTA",
    fecha_pago_cuota    AS "FECHA_PAGO_CUOTA",
    monto_pagado        AS "MONTO_PAGADO",
    saldo_por_pagar     AS "SALDO_POR_PAGAR",
    cod_forma_pago      AS "COD_FORMA_PAGO"
FROM cuota_credito_cliente
WHERE nro_solic_credito IN (2001, 3004, 2004)
ORDER BY nro_solic_credito, nro_cuota;

