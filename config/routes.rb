I18nSonder::Engine.routes.draw do
  post "/translations" => "translations#update"
end
