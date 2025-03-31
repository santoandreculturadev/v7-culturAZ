<?php 
<<<<<<< HEAD

return [
    'app.siteName' => 'Mapas Culturais Base Project',
    'app.siteDescription' => 'O Mapas Culturais é uma plataforma colaborativa que reúne informações sobre agentes, espaços, eventos, projetos culturais e oportunidades',
    
=======
use MapasCulturais\i;

 $_SERVER['SERVER_NAME'] = 'santoandre.sp.gov.br';

return [
    'app.siteName' => 'CulturAZ Santo André',
    'app.siteDescription' => 'CulturaZ Santo André',
   
    'app.geoDivisionsHierarchy' => [
        'bairro' => 'Bairro',
    ],

>>>>>>> 018799a768f4830679b8046f5eadc2635eac1824
    // Define o tema ativo no site principal. Deve ser informado o namespace do tema e neste deve existir uma classe Theme.
    'themes.active' => 'MapasCulturais\Themes\BaseV2',

    // Ids dos selos verificadores. Para utilizar múltiplos selos informe os ids separados por vírgula.
    'app.verifiedSealsIds' => '1', 

];