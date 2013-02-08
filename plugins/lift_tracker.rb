# encoding: utf-8

class LiftTracker
    include Cinch::Plugin
    
    match /lift$/i, method: :getLift
    def getLift(m)
        return unless ignore_nick(m.user.nick).nil?
        getLiftForUser(m, m.user.nick)
    end
    
    match /lift (\S+)$/i, method: :getLiftForUser
    def getLiftForUser(m, user)
        return unless ignore_nick(m.user.nick).nil?
        begin
    		nick = Nick.first_or_create :nick => m.user.nick.downcase
            metric = nick.metric #Get metric preference before switching target
            
            nick = Nick.first :nick => user.downcase
            raise "No such nick" if nick.nil?
            
            lifts = getLifts(nick, metric)
            m.reply "LiftTracker | No lifts for #{user}", true if lifts.empty?
            m.reply "LiftTracker | #{user} (#{getHeight(nick, metric)} #{getWeight(nick, metric)}) | #{lifts.join(", ")}", true
            
    	rescue Exception => x
            error x.message
            error x.backtrace.inspect
			m.reply "LiftTracker | Error | #{x.message}"
		end
    end
    
    match /lift add (\w+) (\d+(?:\.\d+)?)(?: (\d+))?$/i, method: :addLiftNoUnit
    def addLiftNoUnit(m, lift, weight, reps)
        return unless ignore_nick(m.user.nick).nil?
        begin
            nick = Nick.first_or_create :nick => m.user.nick.downcase
            unit = nick.metric ? 'kg' : 'lb'
            addLift(m, lift, weight, unit, reps)
        rescue Exception => x
            error x.message
            error x.backtrace.inspect
        	m.reply "LiftTracker | Error | #{x.message}"
        end
    end
    
    match /lift add (\w+) (\d+(?:\.\d+)?)\s?([a-zA-Z]+)(?: (\d+))?/i, method: :addLift
    def addLift(m, lift, weight, unit, reps)
        return unless ignore_nick(m.user.nick).nil?
        begin
            nick = Nick.first_or_create :nick => m.user.nick.downcase
            reps ||= 1
            case unit
            when /kgs?|kilo(?:gram)?s?/
                unit = 'kg'
            when /lbs?|pounds?/
                unit = 'lb'
            else raise "Invalid unit"
            end
            nick.lifts.first_or_create( :lift => lift.downcase ).update( :weight => weight, :unit => unit, :reps => reps )
            m.reply "LiftTracker | Added lift: #{lift}. Weight: #{weight}#{unit}. Reps: #{reps}", true
        rescue Exception => x
            error x.message
            error x.backtrace.inspect
    		m.reply "LiftTracker | Error | #{x.message}"
        end
    end
    
    match /lift (?:remove|rm) (\w+)/i, method: :removeLift
    def removeLift(m, lift)
        return unless ignore_nick(m.user.nick).nil?
        
        begin
            nick = Nick.first_or_create :nick => m.user.nick.downcase
            lift = nick.lifts.first( :lift => lift.downcase )
            if lift.nil?
                raise "Lift does not exist"
            else
                lift.destroy
                m.reply "LiftTracker | Deleted lift: #{lift.lift}", true
            end
        rescue Exception => x
            error x.message
            error x.backtrace.inspect
        	m.reply "LiftTracker | Error | #{x.message}"
        end
    end
    
    def to_kg (weight)
        (weight / 2.2).round(2)
    end
    
    def to_lb (weight)
        (weight * 2.2).round(2)
    end
    
    def getLifts (nick, metric = true)
        lifts = []
        nick.lifts.all(:fields=>[:lift, :weight, :unit, :reps]).each { |lift|
            if metric
                case lift.unit
                when 'kg'
                    lifts << "#{lift.lift}: #{lift.weight}#{lift.unit}x#{lift.reps}"
                when 'lb'
                    lifts << "#{lift.lift}: #{to_kg(lift.weight)}kgx#{lift.reps}"
                end
            else
                case lift.unit
                when 'kg'
                    lifts << "#{lift.lift}: #{to_lb(lift.weight)}lbx#{lift.reps}"
                when 'lb'
                    lifts << "#{lift.lift}: #{lift.weight}#{lift.unit}x#{lift.reps}"
                end
            end
        }
        debug nick.lifts.all(:fields=>[:lift, :weight, :unit, :reps]).inspect
        debug lifts.inspect
        lifts
    end
    
    def getHeight(nick, metric = true)
        if metric
            "#{(nick.height / 100).round(2)}m"
        else
            "#{(nick.height / 2.54 / 12).round(2)}ft"
        end
    end
    
    def getWeight(nick, metric = true)
        if metric
            "#{nick.weight}kg"
        else
            "#{(nick.weight * 2.2).round(2)}lb"
        end
    end
    
end