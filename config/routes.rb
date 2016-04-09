Rails.application.routes.draw do
	resources :users
	root 'static_pages#home'
	get 'contact' => 'static_pages#contact'
	get 'signup' => 'users#new'
	get 'login' => 'sessions#new'
	post 'login' => 'sessions#create'
	delete 'logout' => 'sessions#destroy'
end
