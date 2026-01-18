*"* use this source file for your ABAP unit test classes
CLASS ltcl_http_proxy DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA: li_cut TYPE REF TO zcl_http_proxy.
    METHODS:
      setup,
      split_proxy_path FOR TESTING RAISING cx_static_check.
ENDCLASS.


CLASS ltcl_http_proxy IMPLEMENTATION.

  METHOD setup.
    li_cut = NEW zcl_http_proxy( ).
  ENDMETHOD.

  METHOD split_proxy_path.
    TYPES: BEGIN OF ty_test,
             path        TYPE string,
             destination TYPE rfcdest,
             target_path TYPE string,
           END OF ty_test.
    TYPES: tt_test TYPE STANDARD TABLE OF ty_test WITH EMPTY KEY.

    DATA: lv_path TYPE string.
    DATA: lv_destination TYPE rfcdest,
          lv_target_path TYPE string.
    DATA: lt_tests TYPE tt_test.

    lt_tests = VALUE tt_test(
      (
        path = '/zproxy/WEBSHOP_STOCK/odata/v4/stock/'
        destination = 'WEBSHOP_STOCK'
        target_path = 'odata/v4/stock' )
      ( path = '/zproxy/WEBSHOP_STOCK/odata/v4/stock/Stock'
        destination = 'WEBSHOP_STOCK'
        target_path = 'odata/v4/stock/Stock' )
      ( path = '/zproxy/ANOTHER_DEST/'
        destination = 'ANOTHER_DEST'
        target_path = '' )
    ).

    LOOP AT lt_tests INTO DATA(ls_test).
      lv_path = ls_test-path.

      li_cut->split_proxy_path(
        EXPORTING
          iv_path        = lv_path
        IMPORTING
          ev_destination = lv_destination
          ev_target_path = lv_target_path
      ).

      cl_abap_unit_assert=>assert_equals(
        act = lv_destination
        exp = ls_test-destination
        msg = |Destination not correctly extracted for path { lv_path }|
      ).

      cl_abap_unit_assert=>assert_equals(
        act = lv_target_path
        exp = ls_test-target_path
        msg = |Target path not correctly extracted for path { lv_path }|
      ).

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
