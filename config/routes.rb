Rails.application.routes.draw do
	resources :users
	root 'static_pages#home'
	get 'contact' => 'static_pages#contact'
	get 'signup' => 'users#new'
end
