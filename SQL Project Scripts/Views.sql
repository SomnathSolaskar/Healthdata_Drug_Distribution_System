/*
************************************************************************
************************************************************************
* Author : Somnath Solaskar                                            *
*                                                                      *
* Scope   : Views                                                      *
*																	   *
* Content: To see order related data and patient-helthcare data	       *		
																	   *
* Date   : 12-28-2021												   *
************************************************************************
************************************************************************
*/

------------------------------------------------------------------------
--					              VIEW ORDER DETAILS
------------------------------------------------------------------------
CREATE OR REPLACE FORCE EDITIONABLE VIEW "ORDERS_OUT" (
    "PATIENT_ID",
    "NAME",
    "ADDRESS",
    "CITY",
    "STATE",
    "ORDER_MED_ID",
    "MEDICINE_ID",
    "MEDICINE_NAME",
    "QUANTITY",
    "STRENGTH",
    "PHONE_NUMBER",
    "CASE_ID",
    "ORDER_ID",
    "ORDER_STATUS"
) DEFAULT COLLATION "USING_NLS_COMP" AS
    SELECT
        p.patient_id,
        p.first_name
        || ' '
        || last_name AS name,
        con.address,
        con.city,
        con.state,
        pr.order_med_id,
        pr.medicine_id,
        med.medicine_name,
        pr.quantity,
        pr.strength,
        con.phone_number,
        c.case_id,
        ord.order_id,
        ord.order_status
    FROM
             patient p
        INNER JOIN contact        con ON p.patient_id = con.patient_id
        INNER JOIN case           c ON p.patient_id = c.patient_id
                             AND p.patient_id = 501045
        INNER JOIN orders         ord ON c.case_id = ord.case_id
                                 AND ord.order_status = 'New'
        INNER JOIN presc_medicine pr ON ord.order_med_id = pr.order_med_id
        INNER JOIN medicines      med ON pr.medicine_id = med.medicine_id;
		
-----------------------------------------------------------------------------------------------------
--					 VIEW PATIENT - PROVIDER DETAILS
-----------------------------------------------------------------------------------------------------
		
CREATE OR REPLACE FORCE EDITIONABLE VIEW "PATIENT_PROVIDER" (
    "PATIENT_ID",
    "FIRST_NAME",
    "HCP_ID",
    "HCP_NAME"
) DEFAULT COLLATION "USING_NLS_COMP" AS
    SELECT
        p.patient_id,
        p.first_name,
        h.hcp_id,
        h.hcp_name
    FROM
             patient p
        INNER JOIN provider_patient pp ON p.patient_id = pp.patient_id
        INNER JOIN hcp              h ON pp.hcp_id = h.hcp_id
    ORDER BY
        p.patient_id;
		
-----------------------------------------------------------------------------------------------------
--					 VIEW PATIENT CLAIMS
-----------------------------------------------------------------------------------------------------

CREATE OR REPLACE FORCE EDITIONABLE VIEW "PATIENT_CLAIMS" (
    "CLIENT_ID",
    "CLIENT_NAME",
    "PATIENT_ID",
    "PATIENT_NAME",
    "PHONE_NUMBER",
    "CLAIM_ID",
    "CLAIM_STATUS"
) DEFAULT COLLATION "USING_NLS_COMP" AS
    SELECT
        cl.client_id,
        cl.client_name,
        p.patient_id,
        p.first_name
        || ' '
        || p.last_name AS patient_name,
        con.phone_number,
        cla.claim_id,
        cla.claim_status
    FROM
             patient p
        INNER JOIN contact      con ON p.patient_id = con.patient_id
        INNER JOIN case         c ON p.patient_id = c.patient_id
                             AND c.updated_date = (
            SELECT
                MAX(updated_date)
            FROM
                case c
            WHERE
                c.patient_id = p.patient_id
        )
        INNER JOIN prescription pr ON c.case_id = pr.case_id
        INNER JOIN claims       cla ON pr.prescription_id = cla.prescription_id
        INNER JOIN client       cl ON cla.client_id = cl.client_id
    ORDER BY
        cl.client_id;
