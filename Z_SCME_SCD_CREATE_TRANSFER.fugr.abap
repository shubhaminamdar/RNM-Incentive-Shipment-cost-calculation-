FUNCTION Z_SCME_SCD_CREATE_TRANSFER
  IMPORTING
    VALUE(IT_INVOICE_DET) TYPE ZSCM_SCD_CT_IM_T
    VALUE(IM_SCD) TYPE CHAR1 OPTIONAL
    VALUE(IM_SES) TYPE CHAR1 OPTIONAL
  EXPORTING
    VALUE(ET_SES_DET) TYPE ZSCM_SCD_CT_EX_T
    VALUE(ET_RETURN) TYPE BAPIRET2_T.



* Program Name  : RFC for SCD Creation & Transfer - Multiple
* Title	        : 8041190
* Create Date	  : 20.01.2020
* Release	      : 6.0
* Author        : Ravi M(NUM_005)
* Functional    : Swapnesh
*----------------------------------------------------------------------*
* CHANGE HISTORY
*----------------------------------------------------------------------*
*Date                User ID       |Description          |Change Label *
*----------------------------------------------------------------------*
*                   |              |                     |
*----------------------------------------------------------------------*

  TYPES : BEGIN OF lty_vfkp,
          fknum  TYPE fknum,
          ebeln  TYPE	ebeln,
          ebelp	 TYPE ebelp,
          lblni	 TYPE lblni,
          rebel  TYPE rebel,
          END OF lty_vfkp,

          BEGIN OF lty_ekbe,
            ebeln  TYPE ebeln,
            ebelp  TYPE ebelp,
            gjahr  TYPE mjahr,
            belnr  TYPE mblnr,
            bewtp  TYPE bewtp,
            bwart  TYPE bwart,
            lfbnr  TYPE lfbnr,
          END OF lty_ekbe,

          BEGIN OF lty_yinvlink,
            scrnum  TYPE zscrnum,
            syear   TYPE zyear,
            lblni   TYPE lblni,
            gjahr	  TYPE mjahr,
            lfbnr	  TYPE lfbnr,
          END OF lty_yinvlink.

  DATA : lt_inv_details TYPE TABLE OF zscm_scd_ct_im_s,
         lt_inv_details_t TYPE TABLE OF zscm_scd_ct_im_s,
         lw_inv_details TYPE zscm_scd_ct_im_s,
         lt_ship_charge TYPE TABLE OF zscm_ship_charge_s,
         lw_ship_charge TYPE zscm_ship_charge_s,
         lw_ship_charge_temp TYPE zscm_ship_charge_s,
         lw_inv_details_t TYPE zscm_scd_ct_im_s,
         lw_ses_ex_det  TYPE zscm_scd_ct_ex_s,
         lt_ses_details TYPE TABLE OF zscm_scd_trans_str,
         lw_ses_details TYPE zscm_scd_trans_str,
         lt_charges     TYPE zscm_ship_charge_t,
         lw_charges     TYPE zscm_ship_charge_s.

  DATA : lw_fknum TYPE fknum,
         lw_vfkk_fknum TYPE fknum,   "8048950.new
         lw_fkpty TYPE fkpty,
         lw_bukrs TYPE bukrs,
         lw_cnt   TYPE i.

  DATA : lw_t180      TYPE t180,
         lw_scd       TYPE v54a0_scdd,
         lt_ref_obj   TYPE v54a0_refobj_tab,
         lw_scd_itm   TYPE v54a0_scd_item,
         lt_scd_itm   TYPE v54a0_scd_item_tab,
         lw_item_wa   TYPE v54a0_scd_item,
         lt_komv      TYPE v54a0_komv_tab,
         lw_komv      LIKE LINE OF lt_komv,
         lt_tknum     TYPE ztknum_tt,
         lw_tknum     TYPE ztknum_st,
         lt_shipment_cost TYPE TABLE OF zst_qwik_ship_cost_val,
         et_return_val  TYPE bapiret2_tt,
         lw_shipment_cost TYPE zst_qwik_ship_cost_val,
         lw_shipment_cost_tmp TYPE zst_qwik_ship_cost_val, "BOC Vandan 16.11.2021
         lt_shipment_charge TYPE TABLE OF zst_qwik_ship_charge_valid,
         lw_shipment_charge TYPE zst_qwik_ship_charge_valid,
         lt_tknum_tmp     TYPE ztknum_tt,
         lw_tknum_tmp     TYPE ztknum_st.         "Eoc Vandan 16.11.2021

  DATA : lt_return   TYPE bapiret2_t,
         lw_return   TYPE bapiret2,
         lw_return_t TYPE bapiret2.
  "(BOC by eswara on 19.07.2020 23:26:13
  DATA : lt_apicode TYPE  zscme_tt_aploc,
          lw_apicode TYPE zscme_ss_aploc .
  "SOC HArdik RD2K9A31T2 "8048517, Qwik Part-payment issue
  DATA : lv_records    TYPE sy-tabix, "int4,
         lv_error_flag TYPE char1,
         lv_last_rec   TYPE char1,
         lt_return_log TYPE STANDARD TABLE OF bapiret2,
         lw_return_log TYPE  bapiret2,
         lv_objkey1    TYPE balnrext.

  DATA : lt_scd_ex TYPE zscm_scd_ct_ex_t,
         lw_scd_ex TYPE zscm_scd_ct_ex_s.

  DATA : lw_index TYPE sy-tabix.

  DATA : lt_vfkp TYPE TABLE OF lty_vfkp,
         lw_vfkp TYPE lty_vfkp,
         lt_ekbe TYPE TABLE OF lty_ekbe,
         lw_ekbe TYPE lty_ekbe,
         lw_ekbe_t TYPE lty_ekbe,
         lt_yinvlink TYPE TABLE OF lty_yinvlink,
         lw_yinvlink TYPE lty_yinvlink.

  CONSTANTS : lc_e TYPE char1 VALUE 'E',
              lc_s TYPE char1 VALUE 'S',
              lc_00 TYPE symsgid VALUE '00',
              lc_001 TYPE symsgno VALUE '001',
              lc_zsce TYPE balobj_d VALUE 'ZSCE',
              lc_sescreate TYPE balsubobj VALUE 'ZQWIK_SES_CREATE',
              lc_fmname TYPE symsgv VALUE ' Called in FM Z_SCME_SCD_CREATE_TRANSFER',
              lc_scd TYPE text10 VALUE 'IM_SCD',
              lc_ses TYPE text10 VALUE 'IM_SES',
              lc_pipe TYPE char1 VALUE '|',
              lc_1 TYPE balprobcl VALUE '1'.
  "EOC HArdik RD2K9A31T2 "8048517, Qwik Part-payment issue

  CONSTANTS : gc_ser TYPE ymtype VALUE 'SER',
              gc_logi TYPE zstype VALUE 'LOGI',
              gc_ekgrp TYPE rvari_vnam VALUE 'ZSCM_SCDTRANSFER_YINVUPD_EKGRP',
              lc_iinvval_bypass TYPE rvari_vnam VALUE 'ZSCM_SCDTRANSFER_INVVAL_BYPASS',
              lc_golive  TYPE rvari_vnam VALUE 'ZSCM_NLP_AMOUNT_GOLIVE'. "Added 8055021

  TYPES : BEGIN OF lty_zlog_stlmntvr,
          name   TYPE zlog_stlmntvr-name,
          shtyp  TYPE zlog_stlmntvr-shtyp,
          active TYPE zlog_stlmntvr-active,
          ekgrp  TYPE zlog_stlmntvr-ekgrp,
        END OF lty_zlog_stlmntvr.

  DATA : lt_zlog_stlmntvr  TYPE TABLE OF lty_zlog_stlmntvr,
         lw_zlog_stlmntvr  TYPE lty_zlog_stlmntvr.

  DATA : lr_ekgrp TYPE RANGE OF ekgrp,
         lw_ekgrp LIKE LINE OF lr_ekgrp.

*BOC Santhosh Chowdary
  DATA: lt_shipment TYPE zscm_nlp_shipment_tt,
        lw_shipment TYPE zscm_nlp_shipment,
        lt_nlp_det TYPE zscm_nlp_shipment_tt,
        lw_nlp_det TYPE zscm_nlp_shipment,
        lw_nlp_golive  TYPE erdat.
*EOC Santhosh Chowdary
  DATA: lt_return_charge_validation TYPE bapiret2_t, "Added by vandan 11.11.2021
        lw_return_charge_validation TYPE bapiret2."Added by vandan 16.11.2021
  SELECT  name
          shtyp
          active
          ekgrp
    FROM zlog_stlmntvr
    INTO TABLE lt_zlog_stlmntvr
    WHERE name IN (gc_ekgrp, lc_iinvval_bypass)   "Chnaged by NUM_005 on 16.02.2020
         AND active = abap_true .
  IF sy-subrc IS INITIAL.
    lw_ekgrp-sign = 'I'.
    lw_ekgrp-option = 'EQ'.
    LOOP AT lt_zlog_stlmntvr INTO lw_zlog_stlmntvr.
      IF lw_zlog_stlmntvr-name = gc_ekgrp AND lw_zlog_stlmntvr-ekgrp IS NOT INITIAL.      "BY NUM_005 on 16.02.2020
        lw_ekgrp-low  = lw_zlog_stlmntvr-ekgrp .
        APPEND lw_ekgrp TO lr_ekgrp.
      ENDIF.
      CLEAR : lw_ekgrp-low .
    ENDLOOP.
  ENDIF.
  SELECT srno
         type
         stype
         werks
         ekgrp
         apcode
         scrldept
        FROM yscm_aploc CLIENT SPECIFIED
        INTO TABLE lt_apicode
        WHERE mandt = sy-mandt
        AND type  = gc_ser
        AND stype = gc_logi
        AND ekgrp IN lr_ekgrp.
  IF sy-subrc IS INITIAL.
    SORT lt_apicode BY srno .
  ENDIF.
  "(EOC by eswara on 19.07.2020 23:26:13
  lt_inv_details[] = it_invoice_det[].

  "Logic to determine Company Code
  READ TABLE lt_inv_details INTO lw_inv_details INDEX 1.
  IF sy-subrc = 0.
    lw_return-type = lc_s.
    lw_return-id = lc_00.
    lw_return-number = lc_001.
    lw_return-message = 'Begin of FM Z_SCME_SCD_CREATE_TRANSFER'(032).
    lw_return-message_v2 = lc_fmname.

    APPEND lw_return TO lt_return_log.
    CLEAR lw_return.

    lw_return-type = lc_s.
    lw_return-id = lc_00.
    lw_return-number = lc_001.
    CONCATENATE lc_scd im_scd lc_ses im_ses INTO lw_return-message SEPARATED BY lc_pipe.
    lw_return-message_v2 = lc_fmname.

    APPEND lw_return TO lt_return_log.
    CLEAR lw_return.

    lv_objkey1 = lw_inv_details-tr_billno.
    CALL FUNCTION 'Z_APPLICATION_LOG_CREATE'
      EXPORTING
        i_objectkey = lv_objkey1
        i_object    = lc_zsce
        i_subobject = lc_sescreate
        it_return   = lt_return_log.

    REFRESH lt_return_log.

    CALL METHOD zcl_fcpl_bukrs=>fcpl_bukrs
      EXPORTING
        im_tplst = lw_inv_details-tplst
      IMPORTING
        ex_bukrs = lw_bukrs.
    IF lw_bukrs IS INITIAL.
      lw_return-type = gc_e.
      lw_return-id = lc_00.
      lw_return-number = lc_001.
      lw_return-message = 'Company code not found'(013).
      APPEND lw_return TO et_return.

      lw_return-message_v2 = lc_fmname.
      APPEND lw_return TO lt_return_log.
      CLEAR lw_return.

      lv_objkey1 = lw_inv_details-tr_billno.
      CALL FUNCTION 'Z_APPLICATION_LOG_CREATE'
        EXPORTING
          i_objectkey = lv_objkey1
          i_object    = lc_zsce
          i_subobject = lc_sescreate
          it_return   = lt_return_log
          i_probclass = lc_1.

      REFRESH lt_return_log.
      RETURN.
    ENDIF.
  ENDIF.

*****  BOC by Ravi M for Cd-8055494 Tr-RD2K9A3FHH on 07.07.2021 *****
  IF it_invoice_det IS NOT INITIAL.
    SELECT fknum
           ebeln
           ebelp
           lblni
           rebel
      FROM vfkp CLIENT SPECIFIED
      INTO TABLE lt_vfkp
      FOR ALL ENTRIES IN it_invoice_det
      WHERE mandt = sy-mandt
      AND   rebel = it_invoice_det-shipment.
    IF sy-subrc = 0.
      SORT lt_vfkp BY ebeln ebelp.

      IF lt_vfkp IS NOT INITIAL.
        SELECT  ebeln
                ebelp
                gjahr
                belnr
                bewtp
                bwart
                lfbnr
          FROM ekbe CLIENT SPECIFIED
          INTO TABLE lt_ekbe
          FOR ALL ENTRIES IN lt_vfkp
          WHERE mandt = sy-mandt
          AND   ebeln = lt_vfkp-ebeln
          AND   ebelp = lt_vfkp-ebelp.
        IF sy-subrc = 0.
          DELETE lt_ekbe WHERE bewtp <> 'E'.
          SORT lt_ekbe BY belnr lfbnr gjahr.

          IF lt_ekbe IS NOT INITIAL.
            SELECT  scrnum
                    syear
                    lblni
                    gjahr
                    lfbnr
              FROM yinvlink CLIENT SPECIFIED
              INTO TABLE lt_yinvlink
              FOR ALL ENTRIES IN lt_ekbe
              WHERE mandt = sy-mandt
              AND   lblni = lt_ekbe-belnr
              AND   lfbnr = lt_ekbe-lfbnr
              AND   gjahr = lt_ekbe-gjahr.
            IF sy-subrc = 0.
              SORT lt_yinvlink BY lblni lfbnr gjahr.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.

  SORT lt_vfkp BY rebel.
  SORT lt_ekbe BY ebeln ebelp lfbnr.
  LOOP AT lt_inv_details INTO lw_inv_details.
    READ TABLE lt_vfkp INTO lw_vfkp WITH KEY rebel = lw_inv_details-shipment BINARY SEARCH.
    IF sy-subrc = 0.
      READ TABLE lt_ekbe INTO lw_ekbe WITH KEY ebeln = lw_vfkp-ebeln
                                               ebelp = lw_vfkp-ebelp
                                               lfbnr = lw_vfkp-lblni BINARY SEARCH.
      IF sy-subrc = 0.

        READ TABLE lt_yinvlink INTO lw_yinvlink WITH KEY lblni = lw_ekbe-belnr
                                                         lfbnr = lw_ekbe-lfbnr
                                                         gjahr = lw_ekbe-gjahr BINARY SEARCH.
        IF sy-subrc = 0.
          IF  lw_yinvlink-scrnum <> lw_inv_details-scroll_no
          OR lw_yinvlink-syear  <> lw_inv_details-syear.



            lw_return-type   = gc_e.
            lw_return-id     = lc_00.
            lw_return-number = lc_001.
            CONCATENATE 'For shipment Number' lw_inv_details-shipment 'SES already posted against scroll number'
                        lw_yinvlink-scrnum INTO lw_return-message SEPARATED BY space.
            APPEND lw_return TO et_return.

            lw_ses_ex_det-shipment  = lw_inv_details-shipment.
            lw_ses_ex_det-tr_billno = lw_inv_details-tr_billno.
            lw_ses_ex_det-scroll_no = lw_inv_details-scroll_no.
            lw_ses_ex_det-ebeln     = lw_vfkp-ebeln.
            lw_ses_ex_det-ebelp     = lw_vfkp-ebelp.
            lw_ses_ex_det-lblni     = lw_vfkp-lblni.
            lw_ses_ex_det-belnr     = lw_ekbe-belnr.
            lw_ses_ex_det-message_type = gc_e.
            CONCATENATE 'For shipment Number' lw_inv_details-shipment 'SES already posted against scroll number'
                        lw_yinvlink-scrnum INTO lw_ses_ex_det-message SEPARATED BY space.
            APPEND lw_ses_ex_det TO et_ses_det.

            lw_return-message_v2 = lc_fmname.
            APPEND lw_return TO lt_return_log.

            lv_objkey1 = lw_inv_details-tr_billno.
            CALL FUNCTION 'Z_APPLICATION_LOG_CREATE'
              EXPORTING
                i_objectkey = lv_objkey1
                i_object    = lc_zsce
                i_subobject = lc_sescreate
                it_return   = lt_return_log
                i_probclass = lc_1.
            RETURN.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
    CLEAR : lw_return, lw_inv_details, lw_vfkp, lw_ekbe, lw_yinvlink, lw_ekbe_t, lw_index, lw_ses_ex_det.
  ENDLOOP.
*****  EOC by Ravi M for Cd-8055494 Tr-RD2K9A3FHH on 07.07.2021 *****

*BOC Santhosh chowdary for NLP amount updation
  SELECT created_on FROM zlog_stlmntvr INTO lw_nlp_golive
                    WHERE name = lc_golive
                    AND   active = abap_true.
  ENDSELECT.

  IF sy-subrc = 0 AND lw_nlp_golive LE sy-datum.

    LOOP AT lt_inv_details INTO lw_inv_details.
      lw_shipment-rp5_shnum = lw_inv_details-shipment.
      APPEND lw_shipment TO lt_shipment.
      CLEAR: lw_shipment, lw_inv_details.
    ENDLOOP.
*NLP Amount fetching RP5 shipment wise
    IF lt_shipment IS NOT INITIAL.
      CALL FUNCTION 'Z_SCM_GET_NLP'
        EXPORTING
          it_shipment = lt_shipment
        IMPORTING
          et_output   = lt_nlp_det
          et_return   = lt_return.
      IF lt_return IS NOT INITIAL.
        et_return = lt_return.
        RETURN.
      ENDIF.
    ENDIF.
  ENDIF.
*EOC Santhosh chowdary for NLP amount updation

  CLEAR : lw_inv_details.
  "SOC HArdik RD2K9A31T2 "8048517, Qwik Part-payment issue
  CLEAR : lv_records,lv_error_flag,lv_last_rec.
  DESCRIBE TABLE lt_inv_details LINES lv_records.
  "EOC HArdik RD2K9A31T2 "8048517, Qwik Part-payment issue
  IF im_scd = abap_true.
    LOOP AT lt_inv_details INTO lw_inv_details.
      CLEAR   : lw_return, lw_return_t, lw_fknum, lw_fkpty.
      REFRESH : lt_return, lt_komv, lt_charges.
      "SOC HArdik RD2K9A31T2 "8048517, Qwik Part-payment issue
*      IF lv_records = sy-tabix.
*        lv_last_rec = 'X'.
*      ENDIF.
      "EOC HArdik RD2K9A31T2 "8048517, Qwik Part-payment issue
      lw_inv_details-bukrs = lw_bukrs.
*    IF im_scd = abap_true.              "If IM_SCD flag is set, then go for SCD creaion
      "FM to creare a Cost Document(SCD)
*>>>>>>>>>>>>>>>>>>>>>>>>>> BOC Cursor <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
*   Added IM_CUMULATIVE_DIST parameter to pass the cumulative distance
*   for the shipment to Z_SCME_SCD_CREATE. This value is read from
*   ZSCM_SCD_CT_IM_S-CUMULATIVE_DIST (new field added to the structure).
*   Z_SCME_SCD_CREATE uses it to populate SAP memory ID 'ZDIST' before
*   calling SD_SCDS_CREATE, ensuring YP28 pricing routine (RV57A914)
*   can correctly compute kwert = kbetr x cumulative_dist.
*   Prerequisite: Add field CUMULATIVE_DIST TYPE CHAR20 to ZSCM_SCD_CT_IM_S.
      CALL FUNCTION 'Z_SCME_SCD_CREATE' DESTINATION 'NONE'
        EXPORTING
          im_shipment        = lw_inv_details-shipment
          im_tr_billno       = lw_inv_details-tr_billno
          im_scroll_no       = lw_inv_details-scroll_no
          im_gl_ac           = lw_inv_details-gl_ac
          im_cost_cnt        = lw_inv_details-cost_cnt
          im_bukrs           = lw_inv_details-bukrs
          it_charge_det      = lw_inv_details-charges
          im_cumulative_dist = lw_inv_details-cumulative_dist
        IMPORTING
          ex_fknum           = lw_fknum
          ex_fkpty           = lw_fkpty
          et_return          = lt_return.
*>>>>>>>>>>>>>>>>>>>>>>>>>> EOC Cursor <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
      IF lw_fknum IS INITIAL.
        "If Cost Documnet creation failed, fill a appropriate error message
        READ TABLE lt_return INTO lw_return_t WITH KEY type = gc_e.
        IF sy-subrc = 0.
          lw_ses_ex_det-message_type = lw_return_t-type.
          lw_ses_ex_det-message      = lw_return_t-message.

          lw_return-type        =  lw_return_t-type.
          lw_return-id          =  lw_return_t-id.
          lw_return-number      =  lw_return_t-number.
          lw_return-message_v1  =  lw_inv_details-shipment.
          lw_return-message     =  lw_return_t-message.
          APPEND lw_return TO et_return.
          "Code added for log 19.09.2020 "8048725 - Service entry creation failure "RD2K9A31YY
          lw_return-type = gc_e.
          lw_return-id = lc_00.
          lw_return-number = lc_001.
          lw_return-message = 'SCD creation error'(024).
          APPEND lw_return TO lt_return.

          lw_return-message_v2 = lc_fmname.
          APPEND lw_return TO lt_return_log.
          CLEAR lw_return.

          APPEND LINES OF lt_return TO lt_return_log.

          CONCATENATE lw_inv_details-tr_billno lw_inv_details-shipment lw_inv_details-scroll_no
            INTO lv_objkey1 SEPARATED BY lc_pipe.
          CALL FUNCTION 'Z_APPLICATION_LOG_CREATE'
            EXPORTING
              i_objectkey = lv_objkey1
              i_object    = lc_zsce
              i_subobject = lc_sescreate
              it_return   = lt_return_log
              i_probclass = lc_1.

          REFRESH lt_return_log.
          "EOC.....8048725 - Service entry creation failure "RD2K9A31YY
        ENDIF.
      ELSE.
        "If Cost Document Creation is success, fill a details for output
        lw_ses_ex_det-shipment  = lw_inv_details-shipment.      "Shipment Number
        lw_ses_ex_det-tr_billno = lw_inv_details-tr_billno.     "Invoice Number
        lw_ses_ex_det-scroll_no = lw_inv_details-scroll_no.     "Scroll Number
        lw_ses_ex_det-fknum     = lw_fknum.                     "Shipment Cost Number
        lw_ses_ex_det-fkpty     = lw_fkpty.                     "Item category shipment costs

*****    Logic to fetch a Shipment Charges
        CALL FUNCTION 'SD_SCD_VIEW'
          EXPORTING
            i_fknum              = lw_fknum
            i_t180               = lw_t180
            i_langu              = sy-langu
            i_opt_document_flow  = gc_x
            i_opt_costs          = gc_x
            i_opt_costs_complete = gc_x
            i_opt_accounts       = gc_x
            i_opt_partners       = gc_x
            i_opt_refobj         = gc_x
            i_opt_refobj_lock    = gc_x
            i_opt_refobj_reduced = gc_x
          CHANGING
            c_scd                = lw_scd
            c_refobj_tab         = lt_ref_obj
          EXCEPTIONS
            scd_not_found        = 1
            no_authority         = 2
            tvtf_type_not_valid  = 3
            refobj_lock          = 4
            refobj_not_found     = 5
            delivery_missing     = 6
            OTHERS               = 7.
        IF sy-subrc = 0.
          LOOP AT lw_scd-x-item INTO lw_scd_itm.        "Loop required, Paraller cursor not possible, max 5 records
            APPEND LINES OF lw_scd_itm-komv TO lt_komv.
            CLEAR : lw_scd_itm.
          ENDLOOP.

          DELETE lt_komv WHERE kwert IS INITIAL.
          LOOP AT lt_komv INTO lw_komv.                 "Loop required, parallel cursor not possible, max 20 records only
            IF lw_komv-kwert IS NOT INITIAL.
              lw_charges-shipment  =  lw_inv_details-shipment.
              lw_charges-tr_billno =  lw_inv_details-tr_billno.
              lw_charges-kschl     =  lw_komv-kschl.
              lw_charges-kbetr     =  lw_komv-kbetr.
              lw_charges-kwert     =  lw_komv-kwert.
              APPEND lw_charges TO lt_charges.
              CLEAR : lw_charges, lw_komv.
            ENDIF.
          ENDLOOP.
          lw_ses_ex_det-charges = lt_charges.
          IF im_ses NE abap_true.
            APPEND lw_ses_ex_det TO et_ses_det.
          ELSE.
            APPEND lw_ses_ex_det TO lt_scd_ex.
          ENDIF.
        ELSE.
          lw_return-type = gc_e.
          lw_return-id = lc_00.
          lw_return-number = lc_001.
          lw_return-message = 'SCD view error'(026).
          APPEND lw_return TO lt_return.

          lw_return-message_v2 = lc_fmname.
          APPEND lw_return TO lt_return_log.
          CLEAR lw_return.

          lv_objkey1 = lw_fknum.
          CALL FUNCTION 'Z_APPLICATION_LOG_CREATE'
            EXPORTING
              i_objectkey = lv_objkey1
              i_object    = lc_zsce
              i_subobject = lc_sescreate
              it_return   = lt_return_log
              i_probclass = lc_1.

          REFRESH lt_return_log.
        ENDIF.
*****    Logic to fetch a Shipment Charges
      ENDIF.
*    ENDIF.
      CLEAR : lw_ses_ex_det, lw_inv_details.
    ENDLOOP.

    CLEAR lw_cnt.
    REFRESH: lt_inv_details_t, lt_shipment_cost, et_return_val.
    lt_inv_details_t = lt_inv_details.
    SORT lt_inv_details_t BY shipment.
    DELETE lt_inv_details_t WHERE shipment IS INITIAL.
    DELETE ADJACENT DUPLICATES FROM lt_inv_details_t COMPARING shipment.
    IF NOT lt_inv_details_t IS INITIAL.
      LOOP AT lt_inv_details_t INTO lw_inv_details.
        lw_tknum-tknum = lw_inv_details-shipment.
        APPEND lw_tknum TO lt_tknum.
        CLEAR: lw_inv_details, lw_tknum.
      ENDLOOP.
      CLEAR lw_inv_details_t.
      READ TABLE lt_inv_details_t INTO lw_inv_details_t INDEX 1.
      IF sy-subrc IS INITIAL.
        lw_shipment_cost-invoice_no = lw_inv_details_t-tr_billno.
        lw_shipment_cost-scroll_no = lw_inv_details_t-scroll_no.
        lw_shipment_cost-scroll_yr = lw_inv_details_t-syear.
        lw_shipment_cost-shipm_cost_no = lw_inv_details_t-fknum.
      ENDIF.
      lw_shipment_cost-shipment_no[] = lt_tknum[].
      IF NOT lw_shipment_cost IS INITIAL.
        READ TABLE lt_zlog_stlmntvr INTO lw_zlog_stlmntvr WITH KEY name = lc_iinvval_bypass shtyp = lw_inv_details_t-shtyp. "Added by NUM_005 on 16.02.2020 Fnc-Swapnesh
        IF sy-subrc <> 0. "Bypass Cost Validation in case of express shipment
          CALL FUNCTION 'Z_QWIK_SHIPMENT_COST_VAL'
            EXPORTING
              im_shipment_cost = lw_shipment_cost
            IMPORTING
              et_return        = et_return_val
            EXCEPTIONS
              no_data_found    = 1
              OTHERS           = 2.
          IF sy-subrc <> 0 OR NOT et_return_val IS INITIAL.
            CLEAR lw_return.
            READ TABLE et_return_val INTO lw_return INDEX 1.
            IF sy-subrc IS INITIAL.
              CLEAR lw_ses_ex_det.
*            et_ses_det = lt_scd_ex . " Eswara
              APPEND LINES OF lt_scd_ex TO et_ses_det.  "NUM_005
              lw_ses_ex_det-shipment  = lw_inv_details_t-shipment.      "Shipment Number
              lw_ses_ex_det-tr_billno = lw_inv_details_t-tr_billno.     "Invoice Number
              lw_ses_ex_det-scroll_no = lw_inv_details_t-scroll_no.     "Scroll Number
              lw_ses_ex_det-fknum     = lw_inv_details_t-fknum.         "Shipment Cost Number
*            lw_ses_ex_det-fkpty     = lw_inv_details_t-.         "Item category shipment costs
              lw_ses_ex_det-message_type = lw_return-type.
              lw_ses_ex_det-message      = lw_return-message.
              lw_ses_ex_det-charges = lw_inv_details_t-charges.
              APPEND lw_ses_ex_det TO et_ses_det.
              APPEND lw_return TO et_return.
              RETURN.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

  ENDIF.

  "Required wait statement before creation of Service Entry Sheet
* WAIT UP TO 1 SECONDS.

  CALL FUNCTION 'DEQUEUE_ALL'.

  IF im_ses = abap_true.
* Shipment Cost validation
    CLEAR lw_shipment_cost_tmp.
    LOOP AT lt_inv_details_t INTO lw_inv_details.
      LOOP AT lw_inv_details-charges INTO lw_ship_charge.
        lw_ship_charge_temp-shipment  =   lw_ship_charge-shipment.
        lw_ship_charge_temp-tr_billno =   lw_ship_charge-tr_billno.
        lw_ship_charge_temp-kschl     =   lw_ship_charge-kschl.
        lw_ship_charge_temp-kwert     =   lw_ship_charge-kwert.
        lw_ship_charge_temp-kbetr     =   lw_ship_charge-kbetr.
        APPEND lw_ship_charge_temp TO lt_ship_charge.
        CLEAR lw_ship_charge_temp.
      ENDLOOP.
      CLEAR lw_ship_charge.
    ENDLOOP.

    lw_shipment_charge-charges[] = lt_ship_charge[].

    READ TABLE lt_inv_details_t INTO lw_inv_details_t INDEX 1.
    IF sy-subrc = 0.
      lw_shipment_charge-invoice_no     = lw_inv_details_t-tr_billno.
      lw_shipment_charge-scroll_no      = lw_inv_details_t-scroll_no.
      lw_shipment_charge-scroll_yr      = lw_inv_details_t-syear.
      lw_shipment_charge-shipm_cost_no  = lw_inv_details_t-fknum.
      CALL FUNCTION 'Z_SCME_SHIPMENT_CHARGE_VALID'
        EXPORTING
          it_shipment_charges = lw_shipment_charge
        IMPORTING
          et_return           = lt_return_charge_validation.

      IF lt_return_charge_validation[] IS NOT INITIAL.
*        LOOP AT lt_return_charge_validation INTO lw_return_charge_validation.
        READ TABLE lt_return_charge_validation INTO lw_return_charge_validation INDEX 1.
        IF sy-subrc = 0.
          APPEND LINES OF lt_scd_ex TO et_ses_det.
          lw_ses_ex_det-shipment     = lw_inv_details_t-shipment.      "Shipment Number
          lw_ses_ex_det-tr_billno    = lw_inv_details_t-tr_billno.     "Invoice Number
          lw_ses_ex_det-scroll_no    = lw_inv_details_t-scroll_no.     "Scroll Number
          lw_ses_ex_det-fknum        = lw_inv_details_t-fknum.         "Shipment Cost Number
          lw_ses_ex_det-message_type = lw_return_charge_validation-type.
          lw_ses_ex_det-message      = lw_return_charge_validation-message.
          lw_ses_ex_det-charges      = lw_inv_details_t-charges.
          APPEND lw_ses_ex_det TO et_ses_det.
          APPEND lw_return_charge_validation TO et_return.

          lt_return_log[] = et_return[].

          lv_objkey1 = lw_inv_details_t-tr_billno.
          CALL FUNCTION 'Z_APPLICATION_LOG_CREATE'
            EXPORTING
              i_objectkey = lv_objkey1
              i_object    = lc_zsce
              i_subobject = lc_sescreate
              it_return   = lt_return_log
              i_probclass = lc_1.

          RETURN.

          CLEAR lw_ses_ex_det.
*        ENDLOOP.
          ENDIF.
      ENDIF.

    ENDIF.

    CLEAR: lw_cnt, lw_tknum.
    REFRESH: lt_inv_details_t, lt_shipment_cost, et_return_val, lt_tknum.
    lt_inv_details_t = lt_inv_details.
    SORT lt_inv_details_t BY shipment.
    DELETE lt_inv_details_t WHERE shipment IS INITIAL.
    DELETE ADJACENT DUPLICATES FROM lt_inv_details_t COMPARING shipment.
    IF NOT lt_inv_details_t IS INITIAL.
      LOOP AT lt_inv_details_t INTO lw_inv_details.
        lw_tknum-tknum = lw_inv_details-shipment.
        APPEND lw_tknum TO lt_tknum.
        CLEAR: lw_inv_details, lw_tknum.
      ENDLOOP.
      CLEAR lw_inv_details_t.
      READ TABLE lt_inv_details_t INTO lw_inv_details_t INDEX 1.
      IF sy-subrc IS INITIAL.
        lw_shipment_cost-invoice_no = lw_inv_details_t-tr_billno.
        lw_shipment_cost-scroll_no = lw_inv_details_t-scroll_no.
        lw_shipment_cost-scroll_yr = lw_inv_details_t-syear.
        lw_shipment_cost-shipm_cost_no = lw_inv_details_t-fknum.
      ENDIF.
      lw_shipment_cost-shipment_no[] = lt_tknum[].
      IF NOT lw_shipment_cost IS INITIAL.
        READ TABLE lt_zlog_stlmntvr INTO lw_zlog_stlmntvr WITH KEY name = lc_iinvval_bypass shtyp = lw_inv_details_t-shtyp. "Added by NUM_005 on 16.02.2020 Fnc-Swapnesh
        IF sy-subrc <> 0. "Bypass Cost Validation in case of express shipment
          CALL FUNCTION 'Z_QWIK_SHIPMENT_COST_VAL'
            EXPORTING
              im_shipment_cost = lw_shipment_cost
            IMPORTING
              et_return        = et_return_val
            EXCEPTIONS
              no_data_found    = 1
              OTHERS           = 2.
          IF sy-subrc <> 0 OR NOT et_return_val IS INITIAL.
            CLEAR lw_return.
            READ TABLE et_return_val INTO lw_return INDEX 1.
            IF sy-subrc IS INITIAL.
              CLEAR lw_ses_ex_det.
*            et_ses_det = lt_scd_ex . " Eswara
              APPEND LINES OF lt_scd_ex TO et_ses_det.
              lw_ses_ex_det-shipment  = lw_inv_details_t-shipment.      "Shipment Number
              lw_ses_ex_det-tr_billno = lw_inv_details_t-tr_billno.     "Invoice Number
              lw_ses_ex_det-scroll_no = lw_inv_details_t-scroll_no.     "Scroll Number
              lw_ses_ex_det-fknum     = lw_inv_details_t-fknum.         "Shipment Cost Number
              lw_ses_ex_det-message_type = lw_return-type.
              lw_ses_ex_det-message      = lw_return-message.
              lw_ses_ex_det-charges = lw_inv_details_t-charges.
              APPEND lw_ses_ex_det TO et_ses_det.
              APPEND lw_return TO et_return.

              lt_return_log[] = et_return[].

              lv_objkey1 = lw_inv_details_t-tr_billno.
              CALL FUNCTION 'Z_APPLICATION_LOG_CREATE'
                EXPORTING
                  i_objectkey = lv_objkey1
                  i_object    = lc_zsce
                  i_subobject = lc_sescreate
                  it_return   = lt_return_log
                  i_probclass = lc_1.

              RETURN.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

* PO Limit Validation
    REFRESH lt_return_log.
    CALL FUNCTION 'Z_SCME_PO_LIMITS_VALIDAT'
      EXPORTING
        it_invoice_det = lt_inv_details
      IMPORTING
        et_return      = lt_return_log.
    READ TABLE lt_return_log  INTO  lw_return_log WITH KEY type = gc_e.
    IF sy-subrc = 0.
*      et_ses_det = lt_scd_ex . " Eswara
      APPEND LINES OF lt_scd_ex TO et_ses_det.
      lw_ses_ex_det-message_type = lw_return_log-type.
      lw_ses_ex_det-message = lw_return_log-message.
      APPEND lw_ses_ex_det TO et_ses_det.
      CLEAR:lw_ses_ex_det.
      et_return = lt_return_log.

      lv_objkey1 = lw_inv_details-tr_billno.
      CALL FUNCTION 'Z_APPLICATION_LOG_CREATE'
        EXPORTING
          i_objectkey = lv_objkey1
          i_object    = lc_zsce
          i_subobject = lc_sescreate
          it_return   = lt_return_log
          i_probclass = lc_1.

      RETURN.
    ENDIF.
    REFRESH lt_return_log.

    SORT lt_scd_ex BY shipment tr_billno scroll_no.
    LOOP AT lt_inv_details INTO lw_inv_details.
      CLEAR   : lw_return, lw_return_t, lw_fknum, lw_fkpty, lw_ses_details, lw_scd_ex.
      REFRESH : lt_return, lt_komv, lt_charges, lt_ses_details.
      "If IM_SES flag is set, then go for SES creation
*    IF im_ses = abap_true AND ( lw_fknum IS NOT INITIAL OR lw_inv_details-fknum IS NOT INITIAL ).\
*      IF lv_records = sy-tabix.
*        lv_last_rec = 'X'.
*      ENDIF.

      READ TABLE lt_scd_ex INTO lw_scd_ex WITH KEY shipment  = lw_inv_details-shipment
                                                   tr_billno = lw_inv_details-tr_billno
                                                   scroll_no = lw_inv_details-scroll_no BINARY SEARCH.
      IF sy-subrc = 0.
        lw_ses_ex_det-shipment  = lw_scd_ex-shipment.      "Shipment Number
        lw_ses_ex_det-tr_billno = lw_scd_ex-tr_billno.     "Invoice Number
        lw_ses_ex_det-scroll_no = lw_scd_ex-scroll_no.     "Scroll Number
        lw_ses_ex_det-fknum     = lw_scd_ex-fknum.         "Shipment Cost Number
        lw_ses_ex_det-fkpty     = lw_scd_ex-fkpty.         "Item category shipment costs
        lw_ses_ex_det-message_type = lw_scd_ex-message_type.
        lw_ses_ex_det-message      = lw_scd_ex-message.
        lw_ses_ex_det-charges = lw_scd_ex-charges.
        IF lw_scd_ex-fknum IS NOT INITIAL.
          lw_fknum = lw_scd_ex-fknum.
        ENDIF.
      ENDIF.

      IF lw_fknum IS INITIAL.
        lw_fknum = lw_inv_details-fknum.
      ENDIF.

* CD 8048950, Start New, Prathamesh Kulkarni/Yogendra Shukla, 02-10-2020
      " DO loop and select query are required inside LOOP to ensure
      " that the Shipment Cost Document is created before further processing.
      DO 60 TIMES.
        SELECT SINGLE fknum
          FROM vfkk
          BYPASSING BUFFER
          INTO lw_vfkk_fknum
          WHERE fknum = lw_fknum.
        IF sy-subrc NE 0.
          " Shipment Cost Document not found.
          WAIT UP TO 1 SECONDS.
        ELSE.
          " Shipment Cost Document is found. Continue processing.
          EXIT.
        ENDIF.
      ENDDO.
      IF lw_vfkk_fknum IS INITIAL.
        " Shipment Cost Document not found after multiple retries
        lw_return-type = gc_e.
        lw_return-id = lc_00.
        lw_return-number = lc_001.
        lw_return-message = 'Shipment Cost Document not found'(031).
        APPEND lw_return TO et_return.

        lw_return-message_v2 = lc_fmname.
        APPEND lw_return TO lt_return_log.
        CLEAR lw_return.

        lv_objkey1 = lw_fknum.
        CALL FUNCTION 'Z_APPLICATION_LOG_CREATE'
          EXPORTING
            i_objectkey = lv_objkey1
            i_object    = lc_zsce
            i_subobject = lc_sescreate
            it_return   = lt_return_log
            i_probclass = lc_1.

        REFRESH lt_return_log.
        " Process next record.
        CONTINUE.
      ENDIF.
* CD 8048950, End New
      "(BOC by eswara on 19.07.2020 23:27:53
      IF lw_inv_details-apcode IS INITIAL.
        READ TABLE lt_apicode INTO lw_apicode INDEX 1  .
        IF sy-subrc IS INITIAL.
          lw_inv_details-apcode   = lw_apicode-apcode.
        ENDIF.
      ENDIF.
      lw_inv_details-bukrs = lw_bukrs.
      "(EOC by eswara on 19.07.2020 23:27:53
*BOC Santhosh CHowdary NLP Amount change
      READ TABLE lt_nlp_det INTO lw_nlp_det WITH KEY rp5_shnum = lw_inv_details-shipment.
      IF sy-subrc NE 0.
        CLEAR lw_nlp_det.
      ENDIF.
*BOC Santhosh CHowdary NLP Amount change

      CLEAR lw_ship_charge.
      READ TABLE lw_inv_details-charges INTO lw_ship_charge INDEX 1.
      IF sy-subrc = 0.

      ENDIF.

      "FM to create a Service Entry Sheet
      CALL FUNCTION 'Z_SCME_SCD_TRANSFER' DESTINATION 'NONE'
        EXPORTING
          im_scd_num     = lw_fknum
          im_scroll_no   = lw_inv_details-scroll_no
          im_bukrs       = lw_inv_details-bukrs
          im_apcode      = lw_inv_details-apcode
          im_syear       = lw_inv_details-syear
          im_error_flg   = lv_error_flag
*         im_last_rec    = lv_last_rec
          im_num_of_rec  = lv_records
          im_nlp_det     = lw_nlp_det
          im_saccode     = lw_ship_charge-saccode
        IMPORTING
          et_ses_details = lt_ses_details
          et_return      = lt_return.
      "SOC HArdik RD2K9A31T2 "8048517, Qwik Part-payment issue
      READ TABLE lt_return  TRANSPORTING NO FIELDS WITH KEY type = 'E'.
      IF sy-subrc = 0.
        lw_ses_ex_det-message_type =
        lv_error_flag = 'X'.
      ENDIF.
      "EOC HArdik RD2K9A31T2 "8048517, Qwik Part-payment issue
      IF lt_ses_details IS INITIAL.
        "IF SES creation failed, fill a appropriate error message
        READ TABLE lt_return INTO lw_return_t WITH KEY type = gc_e.
        IF sy-subrc = 0.
          lw_ses_ex_det-message_type = lw_return_t-type.
          lw_ses_ex_det-message      = lw_return_t-message.

          lw_return-type        =  lw_return_t-type.
          lw_return-id          =  lw_return_t-id.
          lw_return-number      =  lw_return_t-number.
          lw_return-message_v1  =  lw_inv_details-shipment.
          lw_return-message     =  lw_return_t-message.
          APPEND lw_return TO et_return.
          "Code added for log 19.09.2020 "8048725 - Service entry creation failure "RD2K9A31YY
          lw_return-type = gc_e.
          lw_return-id = lc_00.
          lw_return-number = lc_001.
          lw_return-message = 'SCD transfer error'(025).
          APPEND lw_return TO lt_return.

          lw_return-message_v2 = lc_fmname.
          APPEND lw_return TO lt_return_log.
          CLEAR lw_return.

          APPEND LINES OF lt_return TO lt_return_log.

          lv_objkey1 = lw_fknum.
          CALL FUNCTION 'Z_APPLICATION_LOG_CREATE'
            EXPORTING
              i_objectkey = lv_objkey1
              i_object    = lc_zsce
              i_subobject = lc_sescreate
              it_return   = lt_return_log
              i_probclass = lc_1.

          REFRESH lt_return_log.
          "EOC.....8048725 - Service entry creation failure "RD2K9A31YY
        ENDIF.
      ELSE.
        "If SES creation is successful, fill a details for output
        READ TABLE lt_ses_details INTO lw_ses_details INDEX 1.
        IF sy-subrc = 0.
          lw_ses_ex_det-shipment  = lw_inv_details-shipment.
          lw_ses_ex_det-tr_billno = lw_inv_details-tr_billno.
          lw_ses_ex_det-scroll_no = lw_inv_details-scroll_no.
          lw_ses_ex_det-fknum     = lw_fknum.
          lw_ses_ex_det-lblni     = lw_ses_details-lblni.       "Entry Sheet Number
          lw_ses_ex_det-ebeln     = lw_ses_details-ebeln.       "Purchasing Document Number
          lw_ses_ex_det-ebelp     = lw_ses_details-ebelp.       "Item Number of Purchasing Document
          lw_ses_ex_det-mblnr     = lw_ses_details-mblnr.       "Number of Material Document
          lw_ses_ex_det-belnr     = lw_ses_details-belnr.       "Accounting Document Number
        ENDIF.
      ENDIF.
*    ENDIF.

      "Append final values into export parameter
      APPEND lw_ses_ex_det TO et_ses_det.

      CLEAR : lw_inv_details, lw_ses_ex_det,lw_nlp_det.
    ENDLOOP.
  ENDIF.

ENDFUNCTION.
