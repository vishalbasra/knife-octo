# chef gem install colorize
module Octo
  class OctoHelperMethods < Chef::Knife
    require 'json'
    require 'uri'
    require 'net/http'
    require 'openssl'
    require 'colorize'


    def initialize(apikey, instance)
      @apikey = apikey
      @instance = instance
    end

      ## generic helper methods

      def generic_call(method, resource, params)
        instance = @instance
        apikey = @apikey
        output = {
          'response' => 'error',
          'message' => false
        }
          # Format URI object
          uri = "https://#{instance}/api/#{resource}"
          if params
            # logic to do params here for a PUSH / POST, currently not supported
          end
          uri = URI.parse(uri)

          # Format HTTPS request object
          header = { 'X-Octopus-ApiKey' => apikey }
          # Create HTTP object
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          if method == 'GET'
            # put try catch here
            req = Net::HTTP::Get.new(uri.request_uri, header)
          else
            # put try catch here
            req = Net::HTTP::Post.new(uri.request_uri, header)
          end

          # Execute HTTP request
          begin
            result = http.request(req)
          rescue => exception
            print "#{'ERROR'.red} : Could not send request to #{'https://'.red}#{instance.red} - #{exception}\n"
            exit
          else
            "" # had an older colorize block here
          end


          ## Validate result
          case result
            when Net::HTTPOK
              output['response'] = 'ok'
              result_hash = {}
              begin
                result_hash = JSON.parse("#{result.body.force_encoding('UTF-8')}")
              rescue
                result_hash = {
                   'HTTP success type' => "#{result.class.name}"
                }
                if result.body
                  result_hash['body'] = "#{result.body}"
                end
                if result.message
                  result_hash['message'] = "#{result.message}"
                end
               if result['location']
                  result_hash['location'] = "#{result['location']}"
               end
              end
              output['message'] = result_hash
            else
              output['response'] = 'notok'
              output['message'] = "#{'ERROR - '.red} HTTP Response: #{result.class.name}"
              if result.message
                output['message'] += " - Message: #{result.message}"
              end
              if result.body
                output['message'] += "\nCaused by: #{JSON.parse(result.body)['ErrorMessage'].red}\n"
              end
          end
        return output
      end

      def envname_from_id(env_id)
        output = {
          'response' => 'error',
          'message' => false
        }
        request = generic_call('GET', "environments/#{env_id}", false)
        if request['response'] == 'ok'
          output['response'] = 'ok'
          output['message'] = request['message']['Name']
        else
          output['response'] = request['response']
          output ['message'] = request['message']
        end
        return output
      end

      def eid_from_name(env_name)
        output = {
          'response' => 'error',
          'message' => false
        }
        request = generic_call('GET', 'environments/all', false)
        if request['response'] == 'ok'
          parsed_list =  parse_env_list(request['message'],true)
          JSON.parse(parsed_list).each do |some_env|
            if some_env['name'] == env_name
              output['response'] = 'ok'
              output ['message'] = some_env['properties']['id']
            end
          end
          if output['message'].class.to_s == 'FalseClass'
            output['response'] = 'notok'
            output ['message'] = 'Environment name not found'
          end
          else
            output['response'] = request['response']
            output ['message'] = request['message']
        end
        return output
      end

      def mid_from_mname(m_name)
        output = {
          'response' => 'error',
          'message' => false
        }
        request = generic_call('GET', 'machines/all', false)
        if request['response'] == 'ok'
          parsed_list =  parse_machine_list(request['message'],true)
          JSON.parse(parsed_list).each do |some_machine|
            if some_machine['name'] == m_name
              output['response'] = 'ok'
              output ['message'] = some_machine['properties']['id']
            end
          end
          if output['message'].class.to_s == 'FalseClass'
            output['response'] = 'notok'
            output ['message'] = 'Machine name not found'
          end
          else
            output['response'] = request['response']
            output ['message'] = request['message']
        end
        return output
      end

      def create_local_file_by_id(thing)
        tmp_location = "/tmp/ajnfieneom"
        request = generic_call('GET', "#{thing}/all", false)
        things = []
        request['message'].each do |single|
          things << {
            "#{single['Id']}" => "#{single['Name']}"
          }
        end
        if request['response'] == 'ok'
          file = File.open("#{tmp_location}",'w+')
          file.write(JSON.pretty_generate(things))
        end
        file.read
      end

      def create_local_file_by_name(thing)
        tmp_location = "/tmp/ajnfieneoma"
        request = generic_call('GET', "#{thing}/all", false)
        things = []
        request['message'].each do |single|
          things << {
            "#{single['Name']}" => "#{single['Id']}"
          }
        end
        if request['response'] == 'ok'
          file = File.open("#{tmp_location}",'w+')
          file.write(JSON.pretty_generate(things))
          file.close

        end
      end

      def local_file_by_id(e_id,e_name) # couple with create_local_file_by_id ; e_name will be used in a future release
        tmp_location = "/tmp/ajnfieneom"
        file = File.read("#{tmp_location}")
        json_envs = JSON.parse(file)
        json_envs.each do |json_env|
          unless json_env["#{e_id}"].nil?
            return json_env["#{e_id}"]
          end
        end
      end

      def local_file_by_key(key,value) # couple with create_local_file_by_name ; e_name will be used in a future release
        tmp_location = "/tmp/ajnfieneoma"
        file = File.read("#{tmp_location}")
        json_things = JSON.parse(file)
        json_things.each do |json_thing|
          unless json_thing["#{key}"].nil?
            return json_thing["#{key}"]
          end
        end
      end

      def delete_local_file
        tmp_location = "/tmp/ajnfieneom"
        tmp_location_another = "/tmp/ajnfieneoma"
        if File.file?(tmp_location)
          File.delete(tmp_location)
        end
        if File.file?(tmp_location_another)
          File.delete(tmp_location_another)
        end
      end


      ## specific helper methods

      def parse_variable_list (var_list_object,islong)
        instance = @instance
        variable_sets = []
        var_list_object.each do |item|
          if item['ContentType'] == 'Variables'
              if islong.class.to_s == 'TrueClass'
                variable_sets << {
                name: item['Name'],
                properties: {
                  description: item['Description'],
                  id: item['Id'],
                  link: "http://#{instance}/app#/library/variables/#{item['Id']}"
                  }
                }
              else
                variable_sets << item['Name']
              end
          end
        end
        return JSON.pretty_generate(variable_sets)
      end

      def parse_variable_sets_helper (var_obj,islong)
        variable_sets = []
        var_obj['Variables'].each do |item|
          if islong.class.to_s == 'TrueClass' # long
            variable_sets << {
              'name' => item['Name'],
              'value' => item['Value'],
              'isencrypted' => item['IsSensitive'],
              'type' => item['Type'],
              'iseditable' => item['IsEditable'],
              'scope' => item['Scope']['Environment'] # alter this here if we ever use Roles
            }
          else # short
            variable_sets.push(item['Name'])
          end
        end

        ##
        #DO env things here
        if islong.class.to_s == 'TrueClass' # long substitue
          # NEW CREATE ENV FILE
          create_local_file_by_id('environments')
          variable_sets.each do |single_var|
            new_envs = []
            unless single_var['scope'].nil?
              single_var['scope'].each do |env_id|
                new_envs.push(local_file_by_id(env_id,false))
              end
            end
            # SECRET
            single_var['scope'] = new_envs
            if single_var['isencrypted'].class.to_s == 'TrueClass'
              single_var['value'] = '************'
            end
          end
        end

        return JSON.pretty_generate(variable_sets)
      end

      def parse_variable_sets (var_name,islong)
        output = {
          'response' => 'error',
          'message' => false
        }
        create_local_file_by_name('libraryvariablesets')
        unless local_file_by_key(var_name,false).nil?
          var_id = local_file_by_key(var_name,false)
          case var_id
          when String
            ""
          else
            output['response'] = 'notok'
            output['message'] = "Incorrect Variable Set provided"
            return output
          end

          request = generic_call('GET', "/variables/variableset-#{var_id}", false)
          if request['response'] == 'ok'
            output['response'] = 'ok'
            output['message'] = parse_variable_sets_helper(request['message'],islong)
          else
            output['response'] = 'notok'
            output['message'] = request['message']
          end
        end
        #end
        if output['response'].class.to_s == 'FalseClass'
          output['response'] = 'notok'
          output['message'] = "Incorrect Variable Set provided"
        end
        delete_local_file
        return output



      end

      def parse_env_list (env_list_object,islong)
        variable_sets = []
        env_list_object.each do |item|
          if islong.class.to_s == 'TrueClass'
            variable_sets << {
            'name' => item['Name'],
            'properties' => {
              'description'=> item['Description'],
              'id'=> item['Id']
              }
            }
          else
            variable_sets << item['Name']
          end
        end
        return JSON.pretty_generate(variable_sets)
      end

      def parse_env_deets(env_object,islong)
        output = {
          'response' => 'error',
          'message' => false
        }
        variable_sets = []
        env_object['Items'].each do |item|
          if islong.class.to_s == 'TrueClass'
          variable_sets << {
            'name' => item['Name'],
            'properties' => {
              'description' => item['Description'],
              'id' => item['Id'],
              'uri' => item['Endpoint']['Uri'],
              'thumbprint' => item['Thumbprint'],
              'isdisabled' => item['IsDisabled'],
              'health' => item['HealthStatus'],
              'status' => item['Status'],
              'summary' => item['StatusSummary'],
              'isinprocess' => item['IsInProcess'],
              'roles' => item['Roles'],
              'environments' => item['EnvironmentIds']
            }
          }
          else
            variable_sets << item['Name']
          end
        end
        if islong.class.to_s == 'TrueClass'
          # TRANSPOSE ENVS
          variable_sets.each do |single_var|
            new_envs = []
            unless single_var['properties']['environments'].nil?
              single_var['properties']['environments'].each do |env_id|
                new_envs.push(local_file_by_id(env_id,false))
              end
            end
            single_var['properties']['environments'] = new_envs
          end
          # END OF ENV TRANSPOSING
        end
        JSON.pretty_generate(variable_sets)
      end

      def parse_machine_list (m_list_object,islong)
        variable_sets = []
        m_list_object.each do |item|
          if islong.class.to_s == 'TrueClass'
            variable_sets << {
            'name' => item['Name'],
            'properties' => {
              'health'=> item['HealthStatus'],
              'id'=> item['Id']
              }
            }
          else
            variable_sets << item['Name']
          end
        end
        return JSON.pretty_generate(variable_sets)
      end

      def parse_machine_deets (m_object,islong)
        output = {
          'response' => 'error',
          'message' => false
        }
        variable_sets = []
        if islong.class.to_s == 'TrueClass'
          variable_sets << {
            'name' => m_object['Name'],
            'properties' => {
              'id' => m_object['Id'],
              'uri' => m_object['Endpoint']['Uri'],
              'thumbprint' => m_object['Thumbprint'],
              'isdisabled' => m_object['IsDisabled'],
              'health' => m_object['HealthStatus'],
              'status' => m_object['Status'],
              'summary' => m_object['StatusSummary'],
              'isinprocess' => m_object['IsInProcess'],
              'roles' => m_object['Roles'],
              'environments' => m_object['EnvironmentIds']
            }
          }
        else
          variable_sets << {
            'name' => m_object['Name'],
            'uri' => m_object['Endpoint']['Uri'],
            }
        end
        if islong.class.to_s == 'TrueClass'
          variable_sets.each do |single_hash|
            new_environments = []
            single_hash['properties']['environments'].each do |env_id|
              request = envname_from_id(env_id)
              if request['response'] == 'ok'
                new_environments.push(request['message'])
              end
            end
            single_hash['properties']['environments'] = new_environments
          end
        end
        JSON.pretty_generate(variable_sets)
      end

      def parse_project_list (p_list_object,islong,manyitems)
        output = {
          'response' => 'error',
          'message' => false
        }
        instance = @instance
        variable_sets = []
        if manyitems.class.to_s == 'TrueClass' # it's a list
          p_list_object.each do |item|
            if islong.class.to_s == 'TrueClass'
              variable_sets << {
              'name' => item['Name'],
              'properties' => {
                'id'=> item['Id'],
                'deploymentid'=> item['DeploymentProcessId'],
                'variableid'=> item['VariableSetId'],
                'variablesets'=> item['IncludedLibraryVariableSetIds'],
                'url' => "http://#{instance}#{item['Links']['Web']}"
                }
              }
            else
              variable_sets << {
                'name' => item['Name'],
                'url' => "http://#{instance}#{item['Links']['Web']}"
                }
            end
          end
        else # it is not a list and is a single item
          if islong.class.to_s == 'TrueClass'
            ## steps
            steps = generic_call('GET', "deploymentprocesses/#{p_list_object['DeploymentProcessId']}", false)
            if steps['response'] == 'ok'
              process = []
              steps['message']['Steps'].each do |step|
                new_envs = []
                step['Actions'][0]['Environments'].each do |envy_id|
                  new_envs.push(local_file_by_id(envy_id,false))
                end

                excl_envs = []
                step['Actions'][0]['ExcludedEnvironments'].each do |excl_env_id|
                  excl_envs.push(local_file_by_id(excl_env_id,false))
                end

                process << { # not using Id here but it can be used
                  "name" => step['Name'],
                  "packages_required" => step['RequiresPackagesToBeAcquired'],
                  "roles" => step['Properties']['Octopus.Action.TargetRoles'],
                  "condition" => step['Condition'],
                  "start_trigger" => step['StartTrigger'],
                  "environments" => new_envs,
                  "excluded_environments" => excl_envs,
                  "isdisabled" => step['Actions'][0]['IsDisabled'],
                  "details" => step['Actions'][0]['Properties'],
                }
              end
            end
            ## steps end

            variable_sets << {
            'name' => p_list_object['Name'],
            'properties' => {
              'id'=> p_list_object['Id'],
              'deploymentid'=> p_list_object['DeploymentProcessId'],
              'variableid'=> p_list_object['VariableSetId'],
              'variablesets'=> p_list_object['IncludedLibraryVariableSetIds'],
              'url' => "http://#{instance}#{p_list_object['Links']['Web']}",
            },
              'releases' => [],
              'process' => process

            }
          else
            ## steps
            steps = generic_call('GET', "deploymentprocesses/#{p_list_object['DeploymentProcessId']}", false)
            if steps['response'] == 'ok'
              process = []
              steps['message']['Steps'].each do |step|
                process.push(step['Name'])
              end
            end
            ## steps end
            variable_sets << {
              'name' => p_list_object['Name'],
              'id' => p_list_object['Id'],
              'url' => "http://#{instance}#{p_list_object['Links']['Web']}",
              'process' => process
              }
          end
        end
        if islong.class.to_s == 'TrueClass'
          # logic for transforming library variables will go here

          create_local_file_by_id('libraryvariablesets')
          variable_sets.each do |single_var|
            new_vars = []
            unless single_var['properties']['variablesets'].nil?
              single_var['properties']['variablesets'].each do |var_id|
                new_vars.push(local_file_by_id(var_id,false))
              end
            end
            single_var['properties']['variablesets'] = new_vars
          end
          # end of logic for transforming library variables
          case variable_sets
          when Array # single item or manyitems is FALSE
            p_id = variable_sets[0]['properties']['id']
            release_obj = generic_call('GET', "projects/#{p_id}/releases", false)
            if release_obj['response'] = 'ok'
              releases = []
              release_obj['message']['Items'].each do |item|
                  releases << {
                    'version' => item['Version'],
                    'properties' => {
                      'url' => "https://#{instance}#{item['Links']['Web']}",
                      'id' => item['Id'],
                    }
                  }
              end
              variable_sets[0]['releases'] = releases
            else
              output['response'] = 'notok'
              output ['message'] = release_obj['message']
            end
            print "\n"

            output['response'] = 'ok'
            output['message'] = JSON.pretty_generate(variable_sets)

          when Hash # many items or manyitems is TRUE
            output['response'] = 'ok'
            output['message'] = JSON.pretty_generate(variable_sets)

          else
            output['response'] = 'notok'
            output['message'] = 'Could not parse data appropriately.'
            return output
          end
        else
          output['response'] = 'ok'
          output['message'] = JSON.pretty_generate(variable_sets)
        end
        if output['message'].class.to_s == 'FalseClass'
          output['response'] = 'notok'
          output ['message'] = 'Could not parse data appropriately.'
        end
        return output
      end

      def parse_project_release(r_object)
        output = {
          'response' => 'error',
          'message' => false
        }
        instance = @instance
        variable_sets = []
        begin
          package_steps = []
          r_object['SelectedPackages'].each do |package|
            package_steps.push(package['StepName'])
          end
          variable_sets << {
            'Assembled' => r_object['Assembled'],
            'url' => "http://#{instance}#{r_object['Links']['Web']}",
            'package-steps' => package_steps,
            'id' => r_object['Id']

          }
          output['response'] = 'ok'
          output['message'] = JSON.pretty_generate(variable_sets)
        rescue
          output['response'] = 'notok'
          output ['message'] = 'Could not parse data appropriately.'
        end
        return output
      end

      def parse_deployment(d_object,islong)
        output = {
          'response' => 'error',
          'message' => false
        }
        variable_sets = []
        if islong.class.to_s == 'TrueClass' # long result
          begin
            steps = []
            d_object['StepsToExecute'].each do |item|
              steps << {
                'name' => item['ActionName'],
                'properties' => {
                  'num' => item['ActionNumber'],
                  'roles' => item['Roles'],
                  'targets' => item['MachineNames'],
                  'excluded_machines' => item['ExcludedMachines'],
                }
              }
            end
            variable_sets << {
              'steps' => steps
              }
              output['response'] = 'ok'
              output ['message'] = JSON.pretty_generate(variable_sets)
          rescue
            output['response'] = 'notok'
            output ['message'] = 'Could not parse data appropriately.'
          end
          return output
        else # not long
          begin
            steps = []
            d_object['StepsToExecute'].each do |item|
              steps.push("#{item['ActionNumber']} : #{item['ActionName']}")
            end
            variable_sets << {
              'steps' => steps
            }
            output['response'] = 'ok'
            output ['message'] = JSON.pretty_generate(variable_sets)
          rescue
            output['response'] = 'notok'
            output ['message'] = 'Could not parse data appropriately.'
          ensure
            return output
          end # ends
        end
      end


  end

  class Octo < Chef::Knife

    def run
      puts <<-EOH
            ** OCTO COMMANDS **
          You may use these flags
              --long or -l
  The long flag helps with more information

knife octo variables list
knife octo variables show 'name'
knife octo env list
knife octo env show 'name'
knife octo machine list
knife octo machine show 'name'

knife octo project list --  The long option for the said command will display the last 30 releases created for the said project with other details.

            ** project show **
Supports two additional flags in addition to --long
            --release or -r
              --env or -e
knife octo project show 'name'
knife octo project show 'name' -r 'release number'
knife octo project show 'name' -r 'release number' -e 'environment' -- The said command will display the outcome of the process if a deployment were to be triggered on the said environment and release.


EOH
    end
  end

  class OctoVariablesList < Chef::Knife
    banner "** knife octo variables list ** \n knife octo variables list \n knife octo variables list --long \n knife octo variables list -l"
    option :long,
    :short => '-l',
    :long => '--long',
    :boolean => true,
    :description => "Select to use long i.e detailed results"
    def run
      if Chef::Config[:knife][:octo_instance].nil?
        ui.error("Please specify your Octopus Deploy instance in your knife config as -\nknife[:octo_instance] = 'MYOCTO.MYDOMAIN'")
        exit
      end
      if Chef::Config[:knife][:octo_apikey].nil?
        ui.error("Please specify your Octopus API key in your knife config as -\nknife[:octo_apikey]  = 'MYKEY'\nSee Also : https://octopus.com/docs/api-and-integration/api/how-to-create-an-api-key")
        exit
      end
      unless name_args.size == 0
        ui.error("This command does not take any arguments")
        return
      end
      octo_methods = OctoHelperMethods.new(Chef::Config[:knife][:octo_apikey],Chef::Config[:knife][:octo_instance])
      request = octo_methods.generic_call('GET', 'libraryvariablesets/all/', false)
      if request['response'] == 'ok'
        if config[:long]
          print octo_methods.parse_variable_list(request['message'],true)
        else
          print octo_methods.parse_variable_list(request['message'],false)
        end
        print "\n"
      else
        print request['message']
      end
    end
  end

  class OctoVariablesShow < Chef::Knife
    banner "** knife octo variables show 'name' ** \n knife octo variables 'name' -l \n knife octo variables show 'name' --long \n"
    option :long,
    :short => '-l',
    :long => '--long',
    :boolean => true,
    :description => "Select to use long i.e detailed results"

    def run
      if Chef::Config[:knife][:octo_instance].nil?
        ui.error("Please specify your Octopus Deploy instance in your knife config as -\nknife[:octo_instance] = 'MYOCTO.MYDOMAIN'")
        exit
      end
      if Chef::Config[:knife][:octo_apikey].nil?
        ui.error("Please specify your Octopus API key in your knife config as -\nknife[:octo_apikey]  = 'MYKEY'\nSee Also : https://octopus.com/docs/api-and-integration/api/how-to-create-an-api-key")
        exit
      end
      if name_args.size == 0
        ui.error('Specify a variable list!')
        return
      end
      if name_args.size > 1
        ui.error ("You specified two variables!\n Try giving the variable name in quotes.")
        return
      end
      octo_methods = OctoHelperMethods.new(Chef::Config[:knife][:octo_apikey],Chef::Config[:knife][:octo_instance])

      if config[:long]
        if octo_methods.parse_variable_sets(name_args[0],true)['response'] == 'ok'
          octo_methods.create_local_file_by_id('environments')
          print octo_methods.parse_variable_sets(name_args[0],true)['message']
          #delete_local_file
        else
          ui.error(octo_methods.parse_variable_sets(name_args[0],true)['message'])
          exit
        end
      else
        if octo_methods.parse_variable_sets(name_args[0],false)['response'] == 'ok'
          print octo_methods.parse_variable_sets(name_args[0],false)['message']
        else
          ui.error(octo_methods.parse_variable_sets(name_args[0],false)['message'])
          exit
        end

      end
      print "\n"


    end
  end

  class OctoEnvList < Chef::Knife
    banner "** knife octo env list ** \n knife octo env list\n knife octo env list --long \n knife octo env list -l\n"
    option :long,
    :short => '-l',
    :long => '--long',
    :boolean => true,
    :description => "Select to use long i.e detailed results"
    def run
      if Chef::Config[:knife][:octo_instance].nil?
        ui.error("Please specify your Octopus Deploy instance in your knife config as -\nknife[:octo_instance] = 'MYOCTO.MYDOMAIN'")
        exit
      end
      if Chef::Config[:knife][:octo_apikey].nil?
        ui.error("Please specify your Octopus API key in your knife config as -\nknife[:octo_apikey]  = 'MYKEY'\nSee Also : https://octopus.com/docs/api-and-integration/api/how-to-create-an-api-key")
        exit
      end
      unless name_args.size == 0
        ui.error('This command does not take any arguments')
        return
      end
      octo_methods = OctoHelperMethods.new(Chef::Config[:knife][:octo_apikey],Chef::Config[:knife][:octo_instance])
      request = octo_methods.generic_call('GET', 'environments/all', false)
      if request['response'] == 'ok'
        if config[:long]
          print octo_methods.parse_env_list(request['message'],true)
        else
          print octo_methods.parse_env_list(request['message'],false)
        end
        print "\n"
      else
        print request['message']
      end
    end
  end

  class OctoEnvShow < Chef::Knife

    banner "** knife octo env show ** \n knife octo env show\n knife octo env show --long \n knife octo env show -l"
    option :long,
    :short => '-l',
    :long => '--long',
    :boolean => true,
    :description => "Select to use long i.e detailed results"
    def run
      if Chef::Config[:knife][:octo_instance].nil?
        ui.error("Please specify your Octopus Deploy instance in your knife config as -\nknife[:octo_instance] = 'MYOCTO.MYDOMAIN'")
        exit
      end
      if Chef::Config[:knife][:octo_apikey].nil?
        ui.error("Please specify your Octopus API key in your knife config as -\nknife[:octo_apikey]  = 'MYKEY'\nSee Also : https://octopus.com/docs/api-and-integration/api/how-to-create-an-api-key")
        exit
      end
      if name_args.size > 1
        ui.error("You provided two environments\nSupply only one environemnt or try quotes.")
        return
      end

      unless name_args.size == 1
        ui.error('Provide the env name!')
        return
      end

      octo_methods = OctoHelperMethods.new(Chef::Config[:knife][:octo_apikey],Chef::Config[:knife][:octo_instance])
      env_id = octo_methods.eid_from_name("#{name_args[0]}")
      if env_id['response'] == 'ok'

        request = octo_methods.generic_call('GET', "environments/#{env_id['message']}/machines", false)
        if config[:long]
          octo_methods.create_local_file_by_id('environments')
          print octo_methods.parse_env_deets(request['message'],true)
          print "\n"
          octo_methods.delete_local_file
        else
          print octo_methods.parse_env_deets(request['message'],false)
          print "\n"
        end
      else
        ui.error(env_id['message'])
      end
    end
  end

  class OctoMachineList < Chef::Knife

    banner "** knife octo machine list ** \n knife octo machine list \n knife octo machine list --long \n knife octo machine list -l\n"
    option :long,
    :short => '-l',
    :long => '--long',
    :boolean => true,
    :description => "Select to use long i.e detailed results"
    def run
      if Chef::Config[:knife][:octo_instance].nil?
        ui.error("Please specify your Octopus Deploy instance in your knife config as -\nknife[:octo_instance] = 'MYOCTO.MYDOMAIN'")
        exit
      end
      if Chef::Config[:knife][:octo_apikey].nil?
        ui.error("Please specify your Octopus API key in your knife config as -\nknife[:octo_apikey]  = 'MYKEY'\nSee Also : https://octopus.com/docs/api-and-integration/api/how-to-create-an-api-key")
        exit
      end
      unless name_args.size == 0
        ui.error('This command does not take any arguments')
        return
      end
      octo_methods = OctoHelperMethods.new(Chef::Config[:knife][:octo_apikey],Chef::Config[:knife][:octo_instance])
      request = octo_methods.generic_call('GET', 'machines/all', false)
      if request['response'] == 'ok'
        if config[:long]
          print octo_methods.parse_machine_list(request['message'],true)
          print "\n"
        else
          print octo_methods.parse_machine_list(request['message'],false)
          print "\n"
        end
      else
        ui.error(response['message'])
        print "\n"
      end
    end

  end

  class OctoMachineShow < Chef::Knife
    banner "** knife octo machine show 'name' ** \n knife octo machine show 'name' \n knife octo machine show 'name' --long \n knife octo machine show 'name' -l"
    option :long,
    :short => '-l',
    :long => '--long',
    :boolean => true,
    :description => "Select to use long i.e detailed results"

    def run
      if Chef::Config[:knife][:octo_instance].nil?
        ui.error("Please specify your Octopus Deploy instance in your knife config as -\nknife[:octo_instance] = 'MYOCTO.MYDOMAIN'")
        exit
      end
      if Chef::Config[:knife][:octo_apikey].nil?
        ui.error("Please specify your Octopus API key in your knife config as -\nknife[:octo_apikey]  = 'MYKEY'\nSee Also : https://octopus.com/docs/api-and-integration/api/how-to-create-an-api-key")
        exit
      end
      if name_args.size > 1
        ui.error("You provided two machines.\nSupply only one machine name or try quotes.")
        return
      end

      unless name_args.size == 1
        ui.error("#{'Provide the machine name!'.red}")
        return
      end
      octo_methods = OctoHelperMethods.new(Chef::Config[:knife][:octo_apikey],Chef::Config[:knife][:octo_instance])
      m_id = octo_methods.mid_from_mname("#{name_args[0]}")
      if m_id['response'] == 'ok'
        request = octo_methods.generic_call('GET', "machines/#{m_id['message']}", false)
        if config[:long]
          print octo_methods.parse_machine_deets(request['message'],true)
          print "\n"
        else
          print octo_methods.parse_machine_deets(request['message'],false)
          print "\n"
        end
      else
        ui.error(m_id['message'])
      end
    end
  end

  class OctoProjectList < Chef::Knife
    banner "** knife octo project list ** \n knife octo project list \n knife octo project list --long \n knife octo project list -l\n"
    option :long,
    :short => '-l',
    :long => '--long',
    :boolean => true,
    :description => "Select to use long i.e detailed results"
    def run
      if Chef::Config[:knife][:octo_instance].nil?
        ui.error("Please specify your Octopus Deploy instance in your knife config as -\nknife[:octo_instance] = 'MYOCTO.MYDOMAIN'")
        exit
      end
      if Chef::Config[:knife][:octo_apikey].nil?
        ui.error("Please specify your Octopus API key in your knife config as -\nknife[:octo_apikey]  = 'MYKEY'\nSee Also : https://octopus.com/docs/api-and-integration/api/how-to-create-an-api-key")
        exit
      end
      unless name_args.size == 0
        ui.error('This command does not take any arguments')
        return
      end

      octo_methods = OctoHelperMethods.new(Chef::Config[:knife][:octo_apikey],Chef::Config[:knife][:octo_instance])
      request = octo_methods.generic_call('GET', 'projects/all', false)
      if request['response'] == 'ok'
        if config[:long]
          octo_methods.create_local_file_by_id('libraryvariablesets')
          parser = octo_methods.parse_project_list(request['message'],true,true)
          octo_methods.delete_local_file
        else
          parser = octo_methods.parse_project_list(request['message'],false,true)
        end
        if parser['response'] == 'ok'
          print parser['message']
        else
          ui.error(parser['message'])
        end
        print "\n"
      else
        print request['message']
      end
    end

  end

  class OctoProjectShow < Chef::Knife
    banner "** knife octo project show 'name' ** \n knife octo project show 'name' \n knife octo project show 'name' --long \n knife octo project show 'name' -l\n knife octo project show 'name' -r 'release number'\n knife octo project show 'name' -r 'release number' -e 'environment'\n \nknife octo project show 'name' --release 'release number'\n knife octo project show 'name' --release 'release number' --env 'environment'\n\n"
    option :long,
    :short => '-l',
    :long => '--long',
    :boolean => true,
    :description => "Select to use long i.e detailed results"

    option :release,
    :short => '-r',
    :long => '--release',
    :boolean => true,
    :description => "Select to specify a release number"

    option :env,
    :short => '-e',
    :long => '--env',
    :boolean => true,
    :description => "Select to specify an environment"


    def run
      if Chef::Config[:knife][:octo_instance].nil?
        ui.error("Please specify your Octopus Deploy instance in your knife config as -\nknife[:octo_instance] = 'MYOCTO.MYDOMAIN'")
        exit
      end
      if Chef::Config[:knife][:octo_apikey].nil?
        ui.error("Please specify your Octopus API key in your knife config as -\nknife[:octo_apikey]  = 'MYKEY'\nSee Also : https://octopus.com/docs/api-and-integration/api/how-to-create-an-api-key")
        exit
      end

      if name_args.size == 0
        ui.error("#{'Provide the project name!'.red}")
        return
      end
      if (config[:env] && !config[:release])
        ui.error('You cannot specify just an environment, specify a release and an environment.')
        exit
      end
      octo_methods = OctoHelperMethods.new(Chef::Config[:knife][:octo_apikey],Chef::Config[:knife][:octo_instance])
      request = octo_methods.generic_call('GET', "projects/#{name_args[0]}", false)
      case name_args.size
      when 1
        if config[:release]
          ui.error('You specified the release flag but did not provide a release number.')
          exit
        end
        if config[:env]
          ui.error('You cannot specify just an environment, specify a release and an environment.')
          exit
        end
        if request['response'] == 'ok'
          octo_methods.create_local_file_by_id('environments')
          if config[:long]
            parser = octo_methods.parse_project_list(request['message'],true,false)
            octo_methods.delete_local_file
          else
            parser = octo_methods.parse_project_list(request['message'],false,false)
          end
          if parser['response'] == 'ok'
            print parser['message']
          else
            ui.error(parser['message'])
          end
        else
          ui.error(request['message'])
        end
        octo_methods.delete_local_file
      when 2
        if config[:release]
          if request['response'] == 'ok'
            second_request = octo_methods.generic_call('GET', "projects/#{request['message']['Id']}/releases/#{name_args[1]}", false)
            if second_request['response'] == 'ok'
              release_result = octo_methods.parse_project_release(second_request['message'])
              if release_result['response'] == 'ok'
                print release_result['message']
              else
                ui.error(release_result['message'])
              end

            else
              ui.error(second_request['message'])
            end
          else
            ui.error(request['message'])
          end
        end

      when 3
        # if config env
        if (config[:release] && config[:env])
          if request['response'] == 'ok'
            second_request = octo_methods.generic_call('GET', "projects/#{request['message']['Id']}/releases/#{name_args[1]}", false)
            if second_request['response'] == 'ok'
              r_id = second_request['message']['Id']
              env = octo_methods.eid_from_name(name_args[2])
              if env['response'] == 'ok'
                third_request = octo_methods.generic_call('GET', "releases/#{r_id}/deployments/preview/#{env['message']}", false)
                if third_request['response'] == 'ok'
                  if config[:long]
                    d_deets = octo_methods.parse_deployment(third_request['message'],true)
                  else
                    d_deets = octo_methods.parse_deployment(third_request['message'],false)
                  end
                  if d_deets['response'] == 'ok'
                    print d_deets['message']
                  else
                    ui.error(d_deets['message'])
                    exit
                  end
                else
                  ui.error(third_request['message'])
                  exit
                end
              else
                ui.error(env['message'])
              end
            else
              ui.error(second_request['message'])
              exit
            end
          else
            ui.error(request['message'])
          end

        end
        # end env
      else
        ui.error('You can only specify two options')
      end
      print "\n"
    end
  end

# EOF
end
