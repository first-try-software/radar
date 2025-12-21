# Seed data for teams and initiatives

def create_team(attrs, parent: nil, order: 0)
  record = TeamRecord.find_or_initialize_by(name: attrs[:name])
  record.point_of_contact = attrs[:poc]
  record.description = ''
  record.archived = false
  record.save!

  if parent
    TeamsTeamRecord.find_or_create_by!(parent: parent, child: record) do |rel|
      rel.order = order
    end
  end

  attrs[:teams]&.each_with_index do |child_attrs, idx|
    create_team(child_attrs, parent: record, order: idx)
  end

  record
end

# Teams
seed_teams = [
  { name: 'Dashboard', poc: 'Rohan Prabhu', teams: [
    { name: 'Dashboard Platform', poc: 'Alan Ridlehoover', teams: [
      { name: 'Dashboard Build', poc: 'Tarek Refaat' },
      { name: 'Modularization', poc: 'Hoa Newton' },
      { name: 'Ruby Platform', poc: 'Hoa Newton' },
      { name: 'Magnetic', poc: 'Kevin Conboy' },
      { name: 'Magnetize', poc: 'Lalli Flores' },
      { name: 'JS Platform', poc: 'Lalli Flores' }
    ] },
    { name: 'Dashboard Foundational Features', poc: 'Jiann Mok', teams: [
      { name: 'Dashboard Features', poc: 'Pablo Lujambio' },
      { name: 'DashXL', poc: 'Kevin Hurley' },
      { name: 'Dashboard API', poc: 'Philip Dayboch' },
      { name: 'Admins & Auth', poc: 'Josh Chianelli' }
    ] },
    { name: 'Licensing Features', poc: 'Paul Wolfe' },
    { name: 'Licensing Platform', poc: 'Romeeka Gayhart' }
  ] },
  { name: 'SRE', poc: 'Bryant Chae' },
  { name: 'Backend', poc: 'Jay Laney' },
  { name: 'Cloud Test', poc: 'Dickon Wong' }
].freeze

seed_teams.each { |attrs| create_team(attrs) }

# Initiatives
seed_initiatives = [
  { name: 'Developer Experience', poc: 'Alan Ridlehoover' },
  { name: 'Test Environments', poc: 'Dickon Wong' }
].freeze

seed_initiatives.each do |attrs|
  record = InitiativeRecord.find_or_initialize_by(name: attrs[:name])
  record.point_of_contact = attrs[:poc]
  record.description = ''
  record.current_state = 'new'
  record.archived = false
  record.save!
end
