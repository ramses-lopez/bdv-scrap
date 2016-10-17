#!/usr/bin/ruby
require 'watir-webdriver'
require 'byebug'

@b = nil
@base_url = "http://www.bancodevenezuela.com"
@TASK_ID_REGEX = Regexp.new('\/(\d+)\?')

def login(username, password)
	@b.text_field(id: 'email').set(username)
	@b.text_field(id: 'password').set(password)
	@b.button(name: 'commit').click
end

def logout
	@b.link(name: 'salir').click
end

def ejecutar_tarea(resultado)
	#aqui se hace la consulta a tempo
	@b.link(name: 'ejecutar').click
	@b.textarea(name: 'task[internal_comment]').wait_until_present(120)

	type = @b.hidden(id: 'task_type').value

	unless type == 'schedule'
		@b.select(name: 'task[result]').select_value(resultado)
	else
		@b.execute_script("i = document.getElementById('task_appointment_date'); i.readOnly = false; i.value = '#{Time.now.strftime('%d/%m/%Y')}';")
	end

	if resultado == "RECHAZO"
		case type
		when 'review', 'repair_staff', 'review_schedule'
			@b.textarea(name:'task[internal_comment]').set("Fue rechazada la solicitud")
			@b.select(name:'request[val_request_reject_reason_id]').select_value('3')
		when 'schedule'
			@b.textarea(name:'task[internal_comment]').set("Fue contactado bien")
		end
	elsif resultado == "REPARO"
		case type
		when 'review', 'repair_staff', 'review_schedule'
			@b.textarea(name:'task[internal_comment]').set("Fue puesta en reparo")
			@b.textarea(name:'task[customer_comment]').set("Falta algo en la solicitud") if @b.textarea(name:'task[customer_comment]')
			#when 'repair_customer'
		when 'schedule'
			@b.textarea(name:'task[internal_comment]').set("Fue contactado bien")
		end
	else
		case type
		when 'review', 'repair_staff'
			@b.textarea(name:'task[internal_comment]').set("Fue revisada bien")
			#when 'repair_customer'
		when 'schedule', 'review_schedule'
			@b.textarea(name:'task[internal_comment]').set("Fue contactado bien")
		when 'action'
			@b.textarea(name:'task[internal_comment]').set("Fue recibida bien")
		end
	end

	@b.button(id: 'commit_1').click
	print "."
end

def procesar_bandeja_tareas(resultado = :random)
	while @b.link(name: 'ejecutar').exist? do
		begin
			case resultado
			when :ok
				ejecutar_tarea('OK')
			when :repair
				ejecutar_tarea('REPARO')
			when :reject
				ejecutar_tarea('RECHAZO')
			when :random
				ejecutar_tarea(['OK', 'REPARO', 'RECHAZO'].sample)
			end

		rescue Exception => e
			puts "Error: #{e.message}"
		end
	end
end

def enviar_productos

	while !@b.li(class: 'next next_page disabled').exist?
		while @b.link(name: 'enviar').exist? do
			@b.link(name: 'enviar').click
			@b.alert.ok
			sleep(3)
		end

		if @b.li(class: 'next next_page').exist?
			@b.li(class: 'next next_page').links.first.click
			sleep(3)
		end
	end

	while @b.link(name: 'enviar').exist? do
		@b.link(name: 'enviar').click
		@b.alert.ok
	end
end

def init_process
	login('cliente9@pin.com', '_12a34b56c')
	100.times do
		new_request
		fill_panama_account
	end
	enviar_productos
	logout

	#login('juridico10@pin.com', '_12a34b56c')
	#enviar_productos
	#logout
end

def init_panama_account_testing(result = :random)
	login("ve_ejecutivo_de_al@pin.com", "_12a34b56c")
	procesar_bandeja_tareas(result)
	logout

	login("pa_cuenta_mensajero_interno@pin.com", "_12a34b56c")
	procesar_bandeja_tareas(result)
	logout

	login("pa_cuenta_coordinador_fa@pin.com", "_12a34b56c")
	procesar_bandeja_tareas(result)
	logout
end

def init_us_account_testing
	login("us_oficial_de_cumplimiento@pin.com", "_12a34b56c")
	procesar_bandeja_tareas
	logout

	login("us_coordinador_fa@pin.com", "_12a34b56c")
	procesar_bandeja_tareas
	logout
end

def fill_panama_account
	#pagina 1
	@b.text_field(id: "panama_account_initial_deposit_amount").set(10000)
	@b.select_list(id: "panama_account_val_aperture_mode").select_value(3)
	@b.select_list(id: "panama_account_val_funds_source_code").select_value(1)
	@b.select_list(id: "panama_account_val_panama_currency").select_value(1)
	@b.textarea(name: "panama_account[funds_source_explanation]").set("ingresos")
	@b.select_list(id: "panama_account_val_firm_type").select_value(1)
	@b.select_list(id: "panama_account_online_service").select_value(1)
	@b.select_list(id: "panama_account_val_visa_debit_service").select_value(1)
	@b.button(name: 'continue_button').click

	#pagina 2
	@b.select_list(id: "panama_account_val_transfers_allowed").select_value(2)
	@b.select_list(id: "panama_account_val_permanent_transfer").select_value(1)
	@b.select_list(id: "panama_account_transfers_country_1").select_value("PA")
	@b.select_list(id: "panama_account_val_shipping_mode_1").select_value(2)
	@b.select_list(id: "panama_account_val_intermediary").select_value(1)
	@b.button(name: 'continue_button').click


	@b.goto "#{@base_url}/requests"
end

def new_request
	@b.link(id: 'link_new_product').click
	sleep(2)
	@b.select_list(id: 'request_country_code').select_value('PA')
	@b.select_list(id: 'request_product_id').select_value(7) #cuenta de ahorro
	@b.button(name: 'commit').click
end

def start_testing
	@b = Watir::Browser.new
	# page_url = 'https://e-bdvcpx.banvenez.com/clavenetpersonal/inc/BV_TopeIzquierdo_f10.asp'
	# @b.goto page_url
	@b.goto @base_url

	init_time = Time.now
	puts "Inicio > #{init_time}"

	# imagen de bienvenida > id=seguridad2
	@b.element(class: 'seguridad2').click rescue puts 'seguridad2 not found'
	@b.element(class: 'seguridad3').click rescue puts 'seguridad3 not found'
	@b.element(id: 'login_btn_personal_certificado_entrar').click

	# e = @b.element(name: 'notarjeta1')
	# e = @b.element(class: 'txto_Tabls')
	# puts e.inspect
	# e.set(value: 54001985)

	# @b.element(:xpath, "//input[@name='notarjeta1']/").set(value: '54001985')
	# @b.close

	puts "\nFin > #{Time.now} | #{(((Time.now - init_time)/60)).round(4)} minutos"
end

def test_somosport
	b = Watir::Browser.new
	b.goto 'http://ss-management-dev.herokuapp.com/'
	e = b.element(name: 'user-login')
	puts e.inspect
	e.set(value: '13245679')
end


# def test_pdf

# 	pdf_list = []

# 	pdf_list.each do |id|
# 		@b = Watir::Browser.new
# 		@b.goto "https://pin.herokuapp.com/
# 		login("ve_coordinador_de_al@pin.com", "_12a34b56c")
# 		@b.goto "https://pin.herokuapp.com/requests/#{id}/generar_pdf'
# 		break
# 	end

# end

#GO GO GO
# start_testing
test_somosport

