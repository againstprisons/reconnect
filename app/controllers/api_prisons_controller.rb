class ReConnect::Controllers::ApiPrisonsController < ReConnect::Controllers::ApiController
  add_route :post, '/'

  def index
    @prisons = ReConnect::Models::Prison.all.map do |pr|
      {
        :id => pr.id,
        :name => pr.decrypt(:name),
        :physical => pr.decrypt(:physical_address),
        :email => pr.decrypt(:email_address),
      }
    end

    api_json({
      prisons: @prisons,
    })
  end
end
