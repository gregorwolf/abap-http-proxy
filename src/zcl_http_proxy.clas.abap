"! <p class="shorttext synchronized" lang="en">HTTP Proxy with dynamic destination</p>
CLASS zcl_http_proxy DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_http_extension.
    "! <p class="shorttext synchronized" lang="en">Split the path from /zproxy/&lt;SM59 Destination&gt;/&lt;Target Path&gt;</p>
    "!
    "! @parameter iv_path | <p class="shorttext synchronized" lang="en">Full Path</p>
    "! @parameter ev_destination | <p class="shorttext synchronized" lang="en">Destination</p>
    "! @parameter ev_target_path | <p class="shorttext synchronized" lang="en">Target Path</p>
    METHODS split_proxy_path
      IMPORTING
        iv_path        TYPE string
      EXPORTING
        ev_destination TYPE rfcdest
        ev_target_path TYPE string.
  PROTECTED SECTION.
  PRIVATE SECTION.
    DATA: method TYPE string,
          path   TYPE string.
    DATA: destination TYPE rfcdest,
          target_path TYPE string.

ENDCLASS.

CLASS zcl_http_proxy IMPLEMENTATION.

  METHOD if_http_extension~handle_request.
    DATA: lv_response TYPE string,
          lt_fields   TYPE  tihttpnvp.
    me->path = server->request->get_header_field( '~path' ).
    me->method = server->request->get_method( ).

    me->split_proxy_path(
    EXPORTING
      iv_path = me->path
      IMPORTING
      ev_destination = me->destination
      ev_target_path = me->target_path
    ).

    lv_response = |Method { me->method }, Path: { me->path } Destination: { me->destination } Target Path: { me->target_path }|.

    IF me->destination IS NOT INITIAL.
      " Here you would add the logic to perform the HTTP call to the target system
      " using the destination and target_path.
      TRY.
          cl_http_client=>create_by_destination(
            EXPORTING
              destination = me->destination
            IMPORTING
              client      = DATA(lo_http_client)
          ).
        CATCH cx_http_client_exception INTO DATA(lx_create_exception).
          " Handle HTTP client creation failure
          DATA(lv_error_msg) = |HTTP client creation failed: { lx_create_exception->get_text( ) }|.
          server->response->set_status( code = 502 reason = 'Bad Gateway' ).
          server->response->set_cdata( lv_error_msg ).
          RETURN.
      ENDTRY.

      " Read the Accept header from the original request and set it for the proxied request
      DATA(lv_accept) = server->request->get_header_field( 'accept' ).
      lo_http_client->request->set_header_field( name = 'Accept' value = lv_accept ).
      " Read the Content-Type header from the original request and set it for the proxied request
      DATA(lv_content_type_req) = server->request->get_header_field( 'content-type' ).
      lo_http_client->request->set_header_field( name = 'Content-Type' value = lv_content_type_req ).
      " read the request parameters and set them for the proxied request
      server->request->get_form_fields(
        CHANGING
          fields             = lt_fields
      ).
      lo_http_client->request->set_form_fields( lt_fields ).


      " Set the request method and data
      lo_http_client->request->set_method( me->method ).
      IF me->method <> 'GET'.
        lo_http_client->request->set_data( server->request->get_data( ) ).
      ENDIF.
      " Set the target path
      cl_http_utility=>set_request_uri( request = lo_http_client->request uri = me->target_path ).

      TRY.
          " Send the request to the target system
          lo_http_client->send( ).
          " Receive the response from the target system
          lo_http_client->receive( ).
        CATCH cx_http_client_exception INTO DATA(lx_send_receive_exception).
          " Handle connection issues and send/receive failures
          lv_error_msg = |HTTP communication failed: { lx_send_receive_exception->get_text( ) }|.
          server->response->set_status( code = 504 reason = 'Gateway Timeout' ).
          server->response->set_cdata( lv_error_msg ).
          RETURN.
      ENDTRY.

      " Set the response back to the original caller
      server->response->set_data( lo_http_client->response->get_data( ) ).
      " Read and set the Content-Type header
      DATA(lv_content_type) = lo_http_client->response->get_header_field( 'content-type' ).
      server->response->set_header_field( name = 'Content-Type' value = lv_content_type ).
      " Read and set the status code
      lo_http_client->response->get_status(
        IMPORTING
          code   = DATA(lv_status_code)
          reason = DATA(lv_reason)
      ).
      server->response->set_status( code = lv_status_code reason = lv_reason ).
      " Read and set OData-Version
      DATA(lv_odata_version) = lo_http_client->response->get_header_field( 'OData-Version' ).
      IF lv_odata_version IS NOT INITIAL.
        server->response->set_header_field( name = 'OData-Version' value = lv_odata_version ).
      ENDIF.
    ELSE.
      lv_response = 'Invalid proxy path format.'.
      server->response->set_cdata( lv_response ).
    ENDIF.

  ENDMETHOD.

  METHOD split_proxy_path.
    DATA: lv_path        TYPE string,
          lt_parts       TYPE STANDARD TABLE OF string,
          lv_destination TYPE string,
          lv_target_path TYPE string.

    lv_path = iv_path.
    SPLIT lv_path AT '/' INTO TABLE lt_parts.

    " The structure is: /zproxy/<destination>/<target_path>
    " So, lt_parts[2] = destination, lt_parts[3..n] = target_path

    IF lines( lt_parts ) >= 3 AND lt_parts[ 2 ] = 'zproxy'.
      ev_destination = lt_parts[ 3 ].
      lv_target_path = ''.
      LOOP AT lt_parts FROM 4 TO lines( lt_parts ) INTO DATA(lv_part).
        IF lv_target_path IS INITIAL.
          lv_target_path = lv_part.
        ELSE.
          CONCATENATE lv_target_path '/' lv_part INTO lv_target_path.
        ENDIF.
      ENDLOOP.
      ev_target_path = lv_target_path.
    ELSE.
      " Handle error: invalid path format
    ENDIF.
  ENDMETHOD.



ENDCLASS.
